(define-constant ERR_NOT_AUTHORIZED (err u400))
(define-constant ERR_LOAN_NOT_FOUND (err u401))
(define-constant ERR_EXTENSION_EXISTS (err u402))
(define-constant ERR_INVALID_TERMS (err u403))
(define-constant ERR_EXTENSION_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_PROCESSED (err u405))
(define-constant ERR_NOT_ELIGIBLE (err u406))

(define-constant MAX_EXTENSIONS_PER_LOAN u2)
(define-constant MIN_EXTENSION_BLOCKS u500)
(define-constant PROFIT_INCREASE_RATE u5)

(define-data-var next-extension-id uint u1)

(define-map loan-extensions
  { extension-id: uint }
  {
    loan-id: uint,
    borrower: principal,
    original-end-block: uint,
    new-end-block: uint,
    original-profit-share: uint,
    adjusted-profit-share: uint,
    extension-duration: uint,
    status: (string-ascii 20),
    requested-at: uint,
    processed-at: uint,
    justification: (string-ascii 100)
  }
)

(define-map loan-extension-count
  { loan-id: uint }
  { count: uint, total-extended-blocks: uint }
)

(define-public (request-extension 
    (loan-id uint)
    (extension-blocks uint)
    (justification (string-ascii 100)))
  (let (
    (extension-count-data (default-to { count: u0, total-extended-blocks: u0 }
                                      (map-get? loan-extension-count { loan-id: loan-id })))
    (extension-id (var-get next-extension-id))
    (loan-data (unwrap! (contract-call? .Islamic-Finance-Compliant-Lending get-loan loan-id) ERR_LOAN_NOT_FOUND)))
    (if (and 
          (is-eq tx-sender (get borrower loan-data))
          (is-eq (get status loan-data) "active")
          (< (get count extension-count-data) MAX_EXTENSIONS_PER_LOAN)
          (>= extension-blocks MIN_EXTENSION_BLOCKS))
      (let (
        (original-end (+ (get start-block loan-data) (get duration-blocks loan-data)))
        (new-end (+ original-end extension-blocks))
        (adjusted-profit (+ (get profit-share-percentage loan-data) PROFIT_INCREASE_RATE)))
        (map-set loan-extensions
          { extension-id: extension-id }
          {
            loan-id: loan-id,
            borrower: tx-sender,
            original-end-block: original-end,
            new-end-block: new-end,
            original-profit-share: (get profit-share-percentage loan-data),
            adjusted-profit-share: adjusted-profit,
            extension-duration: extension-blocks,
            status: "pending",
            requested-at: stacks-block-height,
            processed-at: u0,
            justification: justification
          })
        (var-set next-extension-id (+ extension-id u1))
        (ok extension-id))
      ERR_NOT_ELIGIBLE)))

(define-public (approve-extension (extension-id uint))
  (let ((ext-data (unwrap! (map-get? loan-extensions { extension-id: extension-id }) ERR_EXTENSION_NOT_FOUND))
        (loan-data (unwrap! (contract-call? .Islamic-Finance-Compliant-Lending get-loan (get loan-id ext-data)) ERR_LOAN_NOT_FOUND)))
    (if (and 
          (is-eq tx-sender (get lender loan-data))
          (is-eq (get status ext-data) "pending"))
      (let ((count-data (default-to { count: u0, total-extended-blocks: u0 }
                                    (map-get? loan-extension-count { loan-id: (get loan-id ext-data) }))))
        (map-set loan-extensions
          { extension-id: extension-id }
          (merge ext-data { status: "approved", processed-at: stacks-block-height }))
        (map-set loan-extension-count
          { loan-id: (get loan-id ext-data) }
          {
            count: (+ (get count count-data) u1),
            total-extended-blocks: (+ (get total-extended-blocks count-data) (get extension-duration ext-data))
          })
        (ok true))
      ERR_NOT_AUTHORIZED)))

(define-public (reject-extension (extension-id uint))
  (let ((ext-data (unwrap! (map-get? loan-extensions { extension-id: extension-id }) ERR_EXTENSION_NOT_FOUND))
        (loan-data (unwrap! (contract-call? .Islamic-Finance-Compliant-Lending get-loan (get loan-id ext-data)) ERR_LOAN_NOT_FOUND)))
    (if (and 
          (is-eq tx-sender (get lender loan-data))
          (is-eq (get status ext-data) "pending"))
      (begin
        (map-set loan-extensions
          { extension-id: extension-id }
          (merge ext-data { status: "rejected", processed-at: stacks-block-height }))
        (ok true))
      ERR_NOT_AUTHORIZED)))

(define-read-only (get-extension (extension-id uint))
  (map-get? loan-extensions { extension-id: extension-id }))

(define-read-only (get-loan-extension-stats (loan-id uint))
  (map-get? loan-extension-count { loan-id: loan-id }))

(define-read-only (calculate-new-repayment (extension-id uint))
  (match (map-get? loan-extensions { extension-id: extension-id })
    ext-data
    (match (contract-call? .Islamic-Finance-Compliant-Lending get-loan (get loan-id ext-data))
      loan-data
      (let ((new-profit (/ (* (get principal-amount loan-data) (get adjusted-profit-share ext-data)) u100)))
        (some (+ (get principal-amount loan-data) new-profit)))
      none)
    none))
