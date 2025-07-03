(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_LOAN_NOT_FOUND (err u102))
(define-constant ERR_LOAN_ALREADY_EXISTS (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_LOAN_NOT_ACTIVE (err u105))
(define-constant ERR_INVALID_PROFIT_SHARE (err u106))
(define-constant ERR_LOAN_EXPIRED (err u107))
(define-constant ERR_EARLY_REPAYMENT (err u108))

(define-constant ERR_INVALID_BUSINESS_TYPE (err u109))
(define-constant ERR_COMPLIANCE_SCORE_EXISTS (err u110))


(define-data-var next-loan-id uint u1)
(define-data-var total-pool-funds uint u0)

(define-map loans
  { loan-id: uint }
  {
    borrower: principal,
    lender: principal,
    principal-amount: uint,
    profit-share-percentage: uint,
    duration-blocks: uint,
    start-block: uint,
    status: (string-ascii 20),
    business-description: (string-ascii 100),
    repaid-amount: uint
  }
)

(define-map lender-pool
  { lender: principal }
  { available-funds: uint, total-invested: uint }
)

(define-map borrower-profile
  { borrower: principal }
  { total-borrowed: uint, successful-loans: uint, default-count: uint }
)

(define-public (deposit-funds (amount uint))
  (let ((current-balance (default-to u0 (get available-funds (map-get? lender-pool { lender: tx-sender })))))
    (if (> amount u0)
      (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set lender-pool
          { lender: tx-sender }
          { 
            available-funds: (+ current-balance amount),
            total-invested: (default-to u0 (get total-invested (map-get? lender-pool { lender: tx-sender })))
          }
        )
        (var-set total-pool-funds (+ (var-get total-pool-funds) amount))
        (ok amount)
      )
      ERR_INVALID_AMOUNT
    )
  )
)

(define-public (request-loan (amount uint) (profit-share uint) (duration uint) (business-desc (string-ascii 100)))
  (let ((loan-id (var-get next-loan-id)))
    (if (and (> amount u0) (<= profit-share u50) (> duration u0))
      (if (is-none (map-get? loans { loan-id: loan-id }))
        (begin
          (map-set loans
            { loan-id: loan-id }
            {
              borrower: tx-sender,
              lender: CONTRACT_OWNER,
              principal-amount: amount,
              profit-share-percentage: profit-share,
              duration-blocks: duration,
              start-block: u0,
              status: "pending",
              business-description: business-desc,
              repaid-amount: u0
            }
          )
          (var-set next-loan-id (+ loan-id u1))
          (ok loan-id)
        )
        ERR_LOAN_ALREADY_EXISTS
      )
      ERR_INVALID_AMOUNT
    )
  )
)

(define-public (approve-loan (loan-id uint) (lender principal))
  (let ((loan-data (unwrap! (map-get? loans { loan-id: loan-id }) ERR_LOAN_NOT_FOUND))
        (lender-data (unwrap! (map-get? lender-pool { lender: lender }) ERR_INSUFFICIENT_FUNDS)))
    (if (>= (get available-funds lender-data) (get principal-amount loan-data))
      (if (is-eq (get status loan-data) "pending")
        (begin
          (try! (as-contract (stx-transfer? (get principal-amount loan-data) tx-sender (get borrower loan-data))))
          (map-set loans
            { loan-id: loan-id }
            (merge loan-data {
              lender: lender,
              start-block: stacks-block-height,
              status: "active"
            })
          )
          (map-set lender-pool
            { lender: lender }
            {
              available-funds: (- (get available-funds lender-data) (get principal-amount loan-data)),
              total-invested: (+ (get total-invested lender-data) (get principal-amount loan-data))
            }
          )
          (ok true)
        )
        ERR_LOAN_NOT_ACTIVE
      )
      ERR_INSUFFICIENT_FUNDS
    )
  )
)

(define-public (repay-loan (loan-id uint))
  (let ((loan-data (unwrap! (map-get? loans { loan-id: loan-id }) ERR_LOAN_NOT_FOUND))
        (profit-amount (/ (* (get principal-amount loan-data) (get profit-share-percentage loan-data)) u100))
        (total-repayment (+ (get principal-amount loan-data) profit-amount)))
    (if (is-eq tx-sender (get borrower loan-data))
      (if (is-eq (get status loan-data) "active")
        (if (>= stacks-block-height (+ (get start-block loan-data) (get duration-blocks loan-data)))
          (begin
            (try! (stx-transfer? total-repayment tx-sender (as-contract tx-sender)))
            (try! (as-contract (stx-transfer? total-repayment tx-sender (get lender loan-data))))
            (map-set loans
              { loan-id: loan-id }
              (merge loan-data {
                status: "completed",
                repaid-amount: total-repayment
              })
            )
            (let ((borrower-data (default-to { total-borrowed: u0, successful-loans: u0, default-count: u0 }
                                            (map-get? borrower-profile { borrower: tx-sender }))))
              (map-set borrower-profile
                { borrower: tx-sender }
                {
                  total-borrowed: (+ (get total-borrowed borrower-data) (get principal-amount loan-data)),
                  successful-loans: (+ (get successful-loans borrower-data) u1),
                  default-count: (get default-count borrower-data)
                }
              )
            )
            (ok total-repayment)
          )
          ERR_EARLY_REPAYMENT
        )
        ERR_LOAN_NOT_ACTIVE
      )
      ERR_NOT_AUTHORIZED
    )
  )
)

(define-public (mark-default (loan-id uint))
  (let ((loan-data (unwrap! (map-get? loans { loan-id: loan-id }) ERR_LOAN_NOT_FOUND)))
    (if (is-eq tx-sender (get lender loan-data))
      (if (and (is-eq (get status loan-data) "active")
               (> stacks-block-height (+ (get start-block loan-data) (get duration-blocks loan-data) u1000)))
        (begin
          (map-set loans
            { loan-id: loan-id }
            (merge loan-data { status: "defaulted" })
          )
          (let ((borrower-data (default-to { total-borrowed: u0, successful-loans: u0, default-count: u0 }
                                          (map-get? borrower-profile { borrower: (get borrower loan-data) }))))
            (map-set borrower-profile
              { borrower: (get borrower loan-data) }
              {
                total-borrowed: (+ (get total-borrowed borrower-data) (get principal-amount loan-data)),
                successful-loans: (get successful-loans borrower-data),
                default-count: (+ (get default-count borrower-data) u1)
              }
            )
          )
          (ok true)
        )
        ERR_LOAN_NOT_ACTIVE
      )
      ERR_NOT_AUTHORIZED
    )
  )
)

(define-public (withdraw-funds (amount uint))
  (let ((lender-data (unwrap! (map-get? lender-pool { lender: tx-sender }) ERR_INSUFFICIENT_FUNDS)))
    (if (and (> amount u0) (<= amount (get available-funds lender-data)))
      (begin
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-set lender-pool
          { lender: tx-sender }
          (merge lender-data { available-funds: (- (get available-funds lender-data) amount) })
        )
        (var-set total-pool-funds (- (var-get total-pool-funds) amount))
        (ok amount)
      )
      ERR_INSUFFICIENT_FUNDS
    )
  )
)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-lender-info (lender principal))
  (map-get? lender-pool { lender: lender })
)

(define-read-only (get-borrower-profile (borrower principal))
  (map-get? borrower-profile { borrower: borrower })
)

(define-read-only (get-total-pool-funds)
  (var-get total-pool-funds)
)

(define-read-only (calculate-repayment (loan-id uint))
  (match (map-get? loans { loan-id: loan-id })
    loan-data 
    (let ((profit (/ (* (get principal-amount loan-data) (get profit-share-percentage loan-data)) u100)))
      (some (+ (get principal-amount loan-data) profit))
    )
    none
  )
)

(define-read-only (is-loan-expired (loan-id uint))
  (match (map-get? loans { loan-id: loan-id })
    loan-data
    (if (> (get start-block loan-data) u0)
      (> stacks-block-height (+ (get start-block loan-data) (get duration-blocks loan-data)))
      false
    )
    false
  )
)


(define-map business-categories
  { category: (string-ascii 20) }
  { halal-score: uint, risk-multiplier: uint }
)

(define-map loan-compliance-scores
  { loan-id: uint }
  { 
    compliance-score: uint,
    business-category-score: uint,
    profit-share-score: uint,
    duration-score: uint,
    borrower-history-score: uint,
    overall-rating: (string-ascii 20)
  }
)

(define-private (initialize-business-categories)
  (begin
    (map-set business-categories { category: "halal-food" } { halal-score: u95, risk-multiplier: u10 })
    (map-set business-categories { category: "islamic-banking" } { halal-score: u100, risk-multiplier: u5 })
    (map-set business-categories { category: "textile" } { halal-score: u85, risk-multiplier: u15 })
    (map-set business-categories { category: "technology" } { halal-score: u90, risk-multiplier: u12 })
    (map-set business-categories { category: "healthcare" } { halal-score: u95, risk-multiplier: u8 })
    (map-set business-categories { category: "education" } { halal-score: u100, risk-multiplier: u5 })
    (map-set business-categories { category: "retail" } { halal-score: u80, risk-multiplier: u18 })
    (map-set business-categories { category: "manufacturing" } { halal-score: u85, risk-multiplier: u20 })
    (map-set business-categories { category: "services" } { halal-score: u88, risk-multiplier: u15 })
    (map-set business-categories { category: "other" } { halal-score: u70, risk-multiplier: u25 })
  )
)

(define-private (calculate-profit-share-score (profit-share uint))
  (if (<= profit-share u15)
    u100
    (if (<= profit-share u25)
      u85
      (if (<= profit-share u35)
        u70
        u50
      )
    )
  )
)

(define-private (calculate-duration-score (duration uint))
  (if (<= duration u5000)
    u100
    (if (<= duration u10000)
      u85
      (if (<= duration u15000)
        u70
        u50
      )
    )
  )
)

(define-private (calculate-borrower-history-score (borrower principal))
  (match (map-get? borrower-profile { borrower: borrower })
    profile
    (let ((success-rate (if (> (get total-borrowed profile) u0)
                           (/ (* (get successful-loans profile) u100) 
                              (+ (get successful-loans profile) (get default-count profile)))
                           u100)))
      (if (>= success-rate u95) u100
        (if (>= success-rate u80) u85
          (if (>= success-rate u70) u70
            u50))))
    u100
  )
)

(define-public (calculate-compliance-score (loan-id uint) (business-category (string-ascii 20)))
  (let ((loan-data (unwrap! (map-get? loans { loan-id: loan-id }) ERR_LOAN_NOT_FOUND))
        (category-data (unwrap! (map-get? business-categories { category: business-category }) ERR_INVALID_BUSINESS_TYPE)))
    (if (is-none (map-get? loan-compliance-scores { loan-id: loan-id }))
      (let ((business-score (get halal-score category-data))
            (profit-score (calculate-profit-share-score (get profit-share-percentage loan-data)))
            (duration-score (calculate-duration-score (get duration-blocks loan-data)))
            (history-score (calculate-borrower-history-score (get borrower loan-data)))
            (overall-score (/ (+ business-score profit-score duration-score history-score) u4)))
        (begin
          (map-set loan-compliance-scores
            { loan-id: loan-id }
            {
              compliance-score: overall-score,
              business-category-score: business-score,
              profit-share-score: profit-score,
              duration-score: duration-score,
              borrower-history-score: history-score,
              overall-rating: (if (>= overall-score u90) "excellent"
                                (if (>= overall-score u80) "good"
                                  (if (>= overall-score u70) "acceptable"
                                    "poor")))
            }
          )
          (ok overall-score)
        )
      )
      ERR_COMPLIANCE_SCORE_EXISTS
    )
  )
)

(define-read-only (get-compliance-score (loan-id uint))
  (map-get? loan-compliance-scores { loan-id: loan-id })
)

(define-read-only (get-business-category-info (category (string-ascii 20)))
  (map-get? business-categories { category: category })
)

(initialize-business-categories)