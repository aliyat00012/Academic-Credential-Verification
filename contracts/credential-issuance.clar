;; Credential Issuance Contract
;; Records degrees and certifications

;; Define data variables
(define-data-var admin principal tx-sender)

;; Define map for credentials
(define-map credentials
  { credential-id: uint }
  {
    institution-id: uint,
    student-id: (string-ascii 50),
    credential-type: (string-ascii 50),
    credential-name: (string-ascii 100),
    issue-date: uint,
    expiration-date: (optional uint),
    metadata: (string-utf8 500),
    revoked: bool
  }
)

;; Define map for institution verification status (simplified)
(define-map verified-institutions
  { institution-id: uint }
  { verified: bool }
)

;; Define map for institution admins (simplified)
(define-map institution-admins
  { institution-id: uint, admin-address: principal }
  { active: bool }
)

(define-data-var credential-counter uint u0)

;; Define error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_INVALID_INSTITUTION u2)
(define-constant ERR_NOT_FOUND u3)
(define-constant ERR_ALREADY_REVOKED u4)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin)))

;; Check if institution is verified (simplified)
(define-read-only (is-institution-verified (institution-id uint))
  (default-to false (get verified (map-get? verified-institutions {institution-id: institution-id}))))

;; Check if caller is an admin for the institution (simplified)
(define-read-only (is-institution-admin (institution-id uint))
  (default-to false (get active (map-get? institution-admins {institution-id: institution-id, admin-address: tx-sender}))))

;; Set institution as verified (admin only)
(define-public (set-institution-verified (institution-id uint) (verified bool))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (map-set verified-institutions
        {institution-id: institution-id}
        {verified: verified}))))

;; Set institution admin (admin only)
(define-public (set-institution-admin (institution-id uint) (admin-address principal) (active bool))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (map-set institution-admins
        {institution-id: institution-id, admin-address: admin-address}
        {active: active}))))

;; Issue a new credential
(define-public (issue-credential
    (institution-id uint)
    (student-id (string-ascii 50))
    (credential-type (string-ascii 50))
    (credential-name (string-ascii 100))
    (expiration-date (optional uint))
    (metadata (string-utf8 500)))
  (let ((credential-id (+ (var-get credential-counter) u1)))
    (begin
      ;; Verify the institution is valid and caller is an admin
      (asserts! (is-institution-verified institution-id) (err ERR_INVALID_INSTITUTION))
      (asserts! (is-institution-admin institution-id) (err ERR_UNAUTHORIZED))

      ;; Set the new credential
      (map-set credentials
        {credential-id: credential-id}
        {
          institution-id: institution-id,
          student-id: student-id,
          credential-type: credential-type,
          credential-name: credential-name,
          issue-date: block-height,
          expiration-date: expiration-date,
          metadata: metadata,
          revoked: false
        })

      ;; Increment the credential counter
      (var-set credential-counter credential-id)
      (ok credential-id))))

;; Revoke a credential (only by issuing institution admin)
(define-public (revoke-credential (credential-id uint))
  (match (map-get? credentials {credential-id: credential-id})
    credential (begin
      ;; Verify the caller is from the issuing institution
      (asserts! (is-institution-admin (get institution-id credential)) (err ERR_UNAUTHORIZED))

      ;; Check if already revoked
      (asserts! (not (get revoked credential)) (err ERR_ALREADY_REVOKED))

      ;; Update the credential to revoked status
      (ok (map-set credentials
          {credential-id: credential-id}
          (merge credential {revoked: true}))))
    (err ERR_NOT_FOUND)))

;; Get credential details
(define-read-only (get-credential (credential-id uint))
  (map-get? credentials {credential-id: credential-id}))

;; Verify if a credential is valid
(define-read-only (is-credential-valid (credential-id uint))
  (match (map-get? credentials {credential-id: credential-id})
    credential (begin
      (if (get revoked credential)
        false
        (match (get expiration-date credential)
          expiry (< block-height expiry)
          true)))
    false))

;; Transfer contract admin rights (admin only)
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (var-set admin new-admin))))

