;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  AquaTrust Protocol
;;  Functionality: decentralized-water-quality-monitoring-system
;;  Description: Decentralized water quality data logging and verification 
;;  Rewarding verified contributors with $AQUA tokens
;;  Developed for Code-for-STX
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; impl-trait commented out because it contained an invalid/malformed trait identifier.
;; Replace the following commented line with a valid trait identifier when available, e.g.:
;; (impl-trait 'SPXXXXXXXXXXXX::sip-010) ;; <-- use the correct principal and trait name
;;(impl-trait 'SP3FBR2AGK5...::sip-010-trait.sip-010-trait) ;; Replace with actual token trait

;; ----------------------------
;; CONSTANTS & VARIABLES
;; ----------------------------
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_NOT_VERIFIED (err u101))
(define-constant ERR_INVALID_ENTRY (err u102))

(define-data-var next-id uint u1)
(define-data-var owner principal tx-sender)

;; ----------------------------
;; DATA STRUCTURES
;; ----------------------------
(define-map water-records
  {id: uint}
  {
    reporter: principal,
    location: (string-ascii 50),
    ph: uint,
    turbidity: uint,
    verified: bool
  }
)

(define-map verified-contributors
  {user: principal}
  {is-verified: bool})

;; ----------------------------
;; TOKEN PARAMETERS (SIP-010)
;; ----------------------------
(define-fungible-token aqua-token)
(define-data-var total-supply uint u0)

;; ----------------------------
;; FUNCTIONS
;; ----------------------------

;; ADMIN FUNCTION: Register a contributor
(define-public (register-contributor (user principal))
  (begin
    (if (is-eq tx-sender (var-get owner))
        (begin
          (map-set verified-contributors {user: user} {is-verified: true})
          (ok true)
        )
        ERR_NOT_AUTHORIZED
    )
  )
)

;; CONTRIBUTORS: Record new water quality data
(define-public (record-water-quality (location (string-ascii 50)) (ph uint) (turbidity uint))
  (let ((user tx-sender))
    (let ((entry (map-get? verified-contributors {user: user})))
      (if (and (is-some entry) (get is-verified (unwrap-panic entry)))
          (let ((id (var-get next-id)))
            (map-set water-records
              {id: id}
              {
                reporter: user,
                location: location,
                ph: ph,
                turbidity: turbidity,
                verified: false
              }
            )
            (var-set next-id (+ id u1))
            (ok id)
          )
          ERR_NOT_VERIFIED
      )
    )
  )
)

;; VERIFIERS: Approve water data and reward contributor
(define-public (verify-sample (id uint))
  (let (
        (record (map-get? water-records {id: id}))
      )
    (if (is-some record)
        (let (
              (data (unwrap-panic record))
              (reporter (get reporter data))
            )
          (map-set water-records
            {id: id}
            (merge data {verified: true})
          )
          (mint-reward reporter)
        )
        ERR_INVALID_ENTRY
    )
  )
)

;; INTERNAL FUNCTION: Mint token reward
(define-private (mint-reward (recipient principal))
  (match (ft-mint? aqua-token u10 recipient)
    success (ok "Reward minted to verified contributor")
    error (err error)
  )
)

;; PUBLIC FUNCTION: View record
(define-read-only (get-water-record (id uint))
  (map-get? water-records {id: id})
)

;; PUBLIC FUNCTION: View contributor verification status
(define-read-only (get-contributor-status (user principal))
  (map-get? verified-contributors {user: user})
)

;; CONTRACT DEPLOYMENT INITIALIZER
(define-public (initialize)
  (begin
    (if (is-eq (var-get owner) tx-sender)
        (ok "Already initialized")
        (begin
          (var-set owner tx-sender)
          (ok "AquaTrust Protocol Initialized")
        )
    )
  )
)
