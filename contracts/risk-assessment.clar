(define-constant ERR_INVALID_BUSINESS_TYPE (err u200))
(define-constant ERR_NEGATIVE_AMOUNT (err u201))
(define-constant MAX_RISK_SCORE u100)
(define-constant MIN_RISK_SCORE u0)

(define-map business-risk-factors
  { business-type: (string-ascii 20) }
  { risk-multiplier: uint }
)

(define-map borrower-risk-scores
  { borrower: principal }
  { 
    current-score: uint,
    last-updated: uint,
    assessment-count: uint
  }
)

(define-private (init-business-risks)
  (begin
    (map-set business-risk-factors { business-type: "tech" } { risk-multiplier: u85 })
    (map-set business-risk-factors { business-type: "retail" } { risk-multiplier: u70 })
    (map-set business-risk-factors { business-type: "manufacturing" } { risk-multiplier: u60 })
    (map-set business-risk-factors { business-type: "services" } { risk-multiplier: u75 })
    (map-set business-risk-factors { business-type: "agriculture" } { risk-multiplier: u50 })
    (map-set business-risk-factors { business-type: "other" } { risk-multiplier: u65 })
    (ok true)
  )
)

(define-private (calculate-default-risk (borrower principal))
  (let ((profile (unwrap! (contract-call? .Islamic-Finance-Compliant-Lending get-borrower-profile borrower) u100)))
    (let ((total-loans (+ (get successful-loans profile) (get default-count profile)))
          (default-count (get default-count profile)))
      (if (is-eq total-loans u0)
        u50
        (let ((default-rate (/ (* default-count u100) total-loans)))
          (if (> default-rate u20)
            (min u100 (+ u60 (* default-rate u2)))
            (max u20 (- u50 (* (- u20 default-rate) u2)))
          )
        )
      )
    )
  )
)

(define-private (calculate-amount-risk (amount uint) (borrower principal))
  (let ((profile (unwrap! (contract-call? .Islamic-Finance-Compliant-Lending get-borrower-profile borrower) u30)))
    (let ((avg-loan (if (> (get successful-loans profile) u0)
                       (/ (get total-borrowed profile) (get successful-loans profile))
                       u0)))
      (if (is-eq avg-loan u0)
        u40
        (let ((ratio (/ (* amount u100) avg-loan)))
          (cond
            ((> ratio u200) u80)
            ((> ratio u150) u60)
            ((> ratio u100) u40)
            (u20)
          )
        )
      )
    )
  )
)

(define-private (get-business-risk (business-type (string-ascii 20)))
  (default-to u65 (get risk-multiplier (map-get? business-risk-factors { business-type: business-type })))
)

(define-public (calculate-risk-score (borrower principal) (loan-amount uint) (business-type (string-ascii 20)))
  (if (> loan-amount u0)
    (let ((default-risk (calculate-default-risk borrower))
          (amount-risk (calculate-amount-risk loan-amount borrower))
          (business-risk (get-business-risk business-type))
          (weighted-score (/ (+ (* default-risk u40) (* amount-risk u35) (* business-risk u25)) u100))
          (final-score (max MIN_RISK_SCORE (min MAX_RISK_SCORE weighted-score))))
      (map-set borrower-risk-scores
        { borrower: borrower }
        {
          current-score: final-score,
          last-updated: stacks-block-height,
          assessment-count: (+ u1 (default-to u0 (get assessment-count (map-get? borrower-risk-scores { borrower: borrower }))))
        }
      )
      (ok final-score)
    )
    ERR_NEGATIVE_AMOUNT
  )
)

(define-read-only (get-risk-score (borrower principal))
  (map-get? borrower-risk-scores { borrower: borrower })
)

(define-read-only (get-risk-category (risk-score uint))
  (cond
    ((<= risk-score u25) "low")
    ((<= risk-score u50) "medium")
    ((<= risk-score u75) "high")
    ("very-high")
  )
)

(define-read-only (get-suggested-profit-share (risk-score uint))
  (cond
    ((<= risk-score u25) u10)
    ((<= risk-score u50) u20)
    ((<= risk-score u75) u35)
    u50
  )
)

(init-business-risks)
