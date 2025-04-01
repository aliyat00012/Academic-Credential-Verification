;; Fraud Detection Contract
;; Identifies suspicious credential patterns

;; Define data variables
(define-data-var admin principal tx-sender)

;; Define map for fraud reports
(define-map fraud-reports
  { report-id: uint }
  {
    reporter: principal,
    credential-id: uint,
    reason: (string-utf8 500),
    report-date: uint,
    status: (string-ascii 20)
  }
)

;; Define map for suspicious patterns
(define-map suspicious-patterns
  { pattern-id: uint }
  {
    pattern-type: (string-ascii 50),
    description: (string-utf8 500),
    severity: uint,
    created-by: principal,
    creation-date: uint
  }
)

;; Define map for credentials (simplified)
(define-map credentials
  { credential-id: uint }
  { exists: bool }
)

(define-data-var report-counter uint u0)
(define-data-var pattern-counter uint u0)

;; Define error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_NOT_FOUND u2)
(define-constant ERR_ALREADY_PROCESSED u3)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin)))

;; Register a credential (simplified)
(define-public (register-credential (credential-id uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (map-set credentials
        {credential-id: credential-id}
        {exists: true}))))

;; Report a potentially fraudulent credential
(define-public (report-fraud (credential-id uint) (reason (string-utf8 500)))
  (let ((report-id (+ (var-get report-counter) u1)))
    (begin
      ;; Verify the credential exists (simplified)
      (asserts! (default-to false (get exists (map-get? credentials {credential-id: credential-id}))) (err ERR_NOT_FOUND))

      (map-set fraud-reports
        {report-id: report-id}
        {
          reporter: tx-sender,
          credential-id: credential-id,
          reason: reason,
          report-date: block-height,
          status: "pending"
        })
      (var-set report-counter report-id)
      (ok report-id))))

;; Process a fraud report (admin only)
(define-public (process-fraud-report (report-id uint) (new-status (string-ascii 20)))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (match (map-get? fraud-reports {report-id: report-id})
      report (begin
        (asserts! (is-eq (get status report) "pending") (err ERR_ALREADY_PROCESSED))
        (ok (map-set fraud-reports
            {report-id: report-id}
            (merge report {status: new-status}))))
      (err ERR_NOT_FOUND))))

;; Add a new suspicious pattern (admin only)
(define-public (add-suspicious-pattern
    (pattern-type (string-ascii 50))
    (description (string-utf8 500))
    (severity uint))
  (let ((pattern-id (+ (var-get pattern-counter) u1)))
    (begin
      (asserts! (is-admin) (err ERR_UNAUTHORIZED))
      (map-set suspicious-patterns
        {pattern-id: pattern-id}
        {
          pattern-type: pattern-type,
          description: description,
          severity: severity,
          created-by: tx-sender,
          creation-date: block-height
        })
      (var-set pattern-counter pattern-id)
      (ok pattern-id))))

;; Get fraud report details
(define-read-only (get-fraud-report (report-id uint))
  (map-get? fraud-reports {report-id: report-id}))

;; Get suspicious pattern details
(define-read-only (get-suspicious-pattern (pattern-id uint))
  (map-get? suspicious-patterns {pattern-id: pattern-id}))

;; Transfer contract admin rights (admin only)
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (var-set admin new-admin))))

