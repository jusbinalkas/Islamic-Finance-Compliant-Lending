(define-constant ERR_NOT_AUTHORIZED (err u300))
(define-constant ERR_INVALID_AMOUNT (err u301))
(define-constant ERR_NO_FEES (err u302))
(define-constant ERR_INVALID_SHARE (err u303))
(define-constant ERR_STAKEHOLDER_EXISTS (err u304))
(define-constant CONTRACT_ADMIN tx-sender)
(define-constant DEFAULT_FEE_RATE u2)

(define-data-var total-fees-collected uint u0)
(define-data-var undistributed-fees uint u0)
(define-data-var platform-fee-rate uint DEFAULT_FEE_RATE)

(define-map stakeholder-shares
  { stakeholder: principal }
  { share-percentage: uint, accumulated-fees: uint, last-claim-block: uint, role: (string-ascii 20) }
)

(define-map fee-collection-history
  { loan-id: uint }
  { fee-amount: uint, collected-at: uint, loan-principal: uint }
)

(define-map distribution-events
  { event-id: uint }
  { distributed-amount: uint, timestamp: uint, recipient-count: uint }
)

(define-data-var next-event-id uint u1)

(define-public (register-stakeholder (stakeholder principal) (share-pct uint) (role (string-ascii 20)))
  (if (is-eq tx-sender CONTRACT_ADMIN)
    (if (<= share-pct u100)
      (if (is-none (map-get? stakeholder-shares { stakeholder: stakeholder }))
        (begin
          (map-set stakeholder-shares
            { stakeholder: stakeholder }
            { share-percentage: share-pct, accumulated-fees: u0, last-claim-block: u0, role: role }
          )
          (ok true)
        )
        ERR_STAKEHOLDER_EXISTS
      )
      ERR_INVALID_SHARE
    )
    ERR_NOT_AUTHORIZED
  )
)

(define-public (collect-loan-fee (loan-id uint) (loan-principal uint))
  (let ((fee-amount (/ (* loan-principal (var-get platform-fee-rate)) u100)))
    (if (> fee-amount u0)
      (begin
        (map-set fee-collection-history
          { loan-id: loan-id }
          { fee-amount: fee-amount, collected-at: stacks-block-height, loan-principal: loan-principal }
        )
        (var-set total-fees-collected (+ (var-get total-fees-collected) fee-amount))
        (var-set undistributed-fees (+ (var-get undistributed-fees) fee-amount))
        (ok fee-amount)
      )
      ERR_INVALID_AMOUNT
    )
  )
)

(define-public (distribute-to-stakeholder (stakeholder principal))
  (let ((stakeholder-data (unwrap! (map-get? stakeholder-shares { stakeholder: stakeholder }) ERR_NOT_AUTHORIZED))
        (share-amount (/ (* (var-get undistributed-fees) (get share-percentage stakeholder-data)) u100)))
    (if (> share-amount u0)
      (begin
        (map-set stakeholder-shares
          { stakeholder: stakeholder }
          (merge stakeholder-data { accumulated-fees: (+ (get accumulated-fees stakeholder-data) share-amount) })
        )
        (ok share-amount)
      )
      ERR_NO_FEES
    )
  )
)

(define-public (claim-fees)
  (let ((stakeholder-data (unwrap! (map-get? stakeholder-shares { stakeholder: tx-sender }) ERR_NOT_AUTHORIZED)))
    (if (> (get accumulated-fees stakeholder-data) u0)
      (begin
        (map-set stakeholder-shares
          { stakeholder: tx-sender }
          (merge stakeholder-data { accumulated-fees: u0, last-claim-block: stacks-block-height })
        )
        (ok (get accumulated-fees stakeholder-data))
      )
      ERR_NO_FEES
    )
  )
)

(define-read-only (get-stakeholder-info (stakeholder principal))
  (map-get? stakeholder-shares { stakeholder: stakeholder })
)

(define-read-only (get-fee-stats)
  (ok {
    total-collected: (var-get total-fees-collected),
    undistributed: (var-get undistributed-fees),
    current-rate: (var-get platform-fee-rate)
  })
)

(define-read-only (get-loan-fee-info (loan-id uint))
  (map-get? fee-collection-history { loan-id: loan-id })
)

(define-read-only (calculate-fee (loan-amount uint))
  (ok (/ (* loan-amount (var-get platform-fee-rate)) u100))
)
