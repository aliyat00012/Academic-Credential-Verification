;; Credential Issuance Contract
;; Records degrees and certifications

;; Import institution verification contract
(use-trait institution-trait .institution-verification.is-institution-verified)

;; Define data variables
(define-map credentials
  ((credential-id uint))
  ((institution-id uint)
   (student-id (string-ascii 50))
   (credential-type (string-ascii 50))
   (credential-name (string-ascii 100))
   (issue-date uint)
   (expiration-date (optional uint))
   (metadata (string-utf8 500))
   (revoked bool)))

(define-data-var credential-counter uint u0)

;; Define error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_INVALID_INSTITUTION u2)
(define-constant ERR_NOT_FOUND u3)
(define-constant ERR_ALREADY_REVOKED u4)

;; Issue a new credential
(define-public (issue-credential
    (institution-id uint)
    (student-id (string-ascii 50))
    (credential-type (string-ascii 50))
    (credential-name (string-ascii 100))
    (expiration-date (optional uint))
    (metadata (string-utf8 500))
    (institution-trait <institution-trait>))
  (let ((credential-id (+ (var-get credential-counter) u1)))
    (begin
      ;; Verify the institution is valid
      (asserts! (is-eq (unwrap! (contract-call? institution-trait is-institution-verified institution-id) (err ERR_INVALID_INSTITUTION)) true)
                (err ERR_INVALID_INSTITUTION))

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

;; Revoke a credential (only by issuing institution)
(define-public (revoke-credential
    (credential-id uint)
    (institution-trait <institution-trait>))
  (match (map-get? credentials {credential-id: credential-id})
    credential (begin
      ;; Verify the caller is from the issuing institution
      (asserts! (is-eq (unwrap! (contract-call? institution-trait is-institution-verified (get institution-id credential))
                               (err ERR_INVALID_INSTITUTION))
                      true)
                (err ERR_UNAUTHORIZED))

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

