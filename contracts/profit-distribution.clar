(define-constant ERR_NO_PROFITS (err u200))
(define-constant ERR_DISTRIBUTION_EXISTS (err u201))
(define-constant ERR_INSUFFICIENT_BALANCE (err u202))
(define-constant PROFIT_DISTRIBUTION_PERCENTAGE u30)

(define-data-var total-profit-pool uint u0)
(define-data-var last-distribution-block uint u0)

(define-map profit-shares
  { lender: principal }
  { earned-profits: uint, last-claimed-block: uint, investment-weight: uint }
)

(define-map completed-loan-profits
  { loan-id: uint }
  { profit-amount: uint, distributed: bool }
)

(define-public (record-loan-profit (loan-id uint) (total-profit uint))
  (if (is-none (map-get? completed-loan-profits { loan-id: loan-id }))
    (let ((pool-contribution (/ (* total-profit PROFIT_DISTRIBUTION_PERCENTAGE) u100)))
      (map-set completed-loan-profits
        { loan-id: loan-id }
        { profit-amount: total-profit, distributed: false }
      )
      (var-set total-profit-pool (+ (var-get total-profit-pool) pool-contribution))
      (ok pool-contribution)
    )
    ERR_DISTRIBUTION_EXISTS
  )
)

(define-public (distribute-profits)
  (let ((current-pool (var-get total-profit-pool)))
    (if (> current-pool u0)
      (begin
        (var-set last-distribution-block stacks-block-height)
        (var-set total-profit-pool u0)
        (ok current-pool)
      )
      ERR_NO_PROFITS
    )
  )
)

(define-public (calculate-lender-share (lender principal) (total-invested uint))
  (let ((current-share (default-to { earned-profits: u0, last-claimed-block: u0, investment-weight: u0 }
                                   (map-get? profit-shares { lender: lender })))
        (pool-amount (var-get total-profit-pool))
        (weight-ratio (if (> total-invested u0) (/ (* total-invested u100) total-invested) u0))
        (profit-share (/ (* pool-amount weight-ratio) u100)))
    (if (> profit-share u0)
      (begin
        (map-set profit-shares
          { lender: lender }
          {
            earned-profits: (+ (get earned-profits current-share) profit-share),
            last-claimed-block: stacks-block-height,
            investment-weight: total-invested
          }
        )
        (ok profit-share)
      )
      (ok u0)
    )
  )
)

(define-public (claim-profit-share)
  (let ((share-data (unwrap! (map-get? profit-shares { lender: tx-sender }) ERR_NO_PROFITS)))
    (if (> (get earned-profits share-data) u0)
      (begin
        (try! (as-contract (stx-transfer? (get earned-profits share-data) tx-sender tx-sender)))
        (map-set profit-shares
          { lender: tx-sender }
          (merge share-data { earned-profits: u0 })
        )
        (ok (get earned-profits share-data))
      )
      ERR_INSUFFICIENT_BALANCE
    )
  )
)

(define-read-only (get-profit-share (lender principal))
  (map-get? profit-shares { lender: lender })
)

(define-read-only (get-total-profit-pool)
  (var-get total-profit-pool)
)

(define-read-only (get-loan-profit-info (loan-id uint))
  (map-get? completed-loan-profits { loan-id: loan-id })
)
