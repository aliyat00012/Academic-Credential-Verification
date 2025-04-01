;; Institution Verification Contract
;; This contract validates legitimate educational entities

;; Define data variables
(define-data-var admin principal tx-sender)

;; Define map for institutions
(define-map institutions
  { institution-id: uint }
  {
    name: (string-ascii 100),
    country: (string-ascii 50),
    website: (string-ascii 100),
    verified: bool,
    registration-date: uint
  }
)

;; Define map for institution admins
(define-map institution-admins
  { institution-id: uint, admin-address: principal }
  { active: bool }
)

;; Define error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_REGISTERED u2)
(define-constant ERR_NOT_FOUND u3)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin)))

;; Register a new institution (admin only)
(define-public (register-institution
    (institution-id uint)
    (name (string-ascii 100))
    (country (string-ascii 50))
    (website (string-ascii 100)))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? institutions {institution-id: institution-id})) (err ERR_ALREADY_REGISTERED))
    (ok (map-set institutions
      {institution-id: institution-id}
      {
        name: name,
        country: country,
        website: website,
        verified: false,
        registration-date: block-height
      }))))

;; Verify an institution (admin only)
(define-public (verify-institution (institution-id uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (match (map-get? institutions {institution-id: institution-id})
      institution (ok (map-set institutions
                      {institution-id: institution-id}
                      (merge institution {verified: true})))
      (err ERR_NOT_FOUND))))

;; Add an admin for an institution (contract admin only)
(define-public (add-institution-admin (institution-id uint) (admin-address principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-some (map-get? institutions {institution-id: institution-id})) (err ERR_NOT_FOUND))
    (ok (map-set institution-admins
        {institution-id: institution-id, admin-address: admin-address}
        {active: true}))))

;; Check if an address is an admin for an institution
(define-read-only (is-institution-admin (institution-id uint) (admin-address principal))
  (default-to false (get active (map-get? institution-admins {institution-id: institution-id, admin-address: admin-address}))))

;; Check if an institution is verified
(define-read-only (is-institution-verified (institution-id uint))
  (default-to false (get verified (map-get? institutions {institution-id: institution-id}))))

;; Get institution details
(define-read-only (get-institution (institution-id uint))
  (map-get? institutions {institution-id: institution-id}))

;; Transfer contract admin rights (admin only)
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (var-set admin new-admin))))

