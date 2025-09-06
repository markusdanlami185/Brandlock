;; Trademark Domain Verification System - Protect trademark holders from cybersquatting
;; Enables verification of domain ownership and trademark-domain relationships

(define-constant err-trademark-not-found (err u300))
(define-constant err-domain-not-found (err u301))
(define-constant err-already-verified (err u302))
(define-constant err-verification-failed (err u303))
(define-constant err-not-trademark-owner (err u304))
(define-constant err-invalid-domain (err u305))
(define-constant err-challenge-expired (err u306))
(define-constant err-insufficient-fee (err u307))

(define-data-var verification-id-nonce uint u0)
(define-data-var domain-verification-fee uint u500000) ;; 0.5 STX
(define-data-var challenge-duration uint u144) ;; ~24 hours

;; Domain verification records
(define-map domain-verifications
  uint
  {
    trademark-name: (string-ascii 50),
    domain-name: (string-ascii 100),
    trademark-owner: principal,
    verification-method: (string-ascii 20), ;; "dns-txt", "file-upload", "meta-tag"
    challenge-code: (string-ascii 64),
    created-at: uint,
    expires-at: uint,
    verified: bool,
    verified-at: uint
  }
)

;; Trademark-domain relationships
(define-map trademark-domains
  (string-ascii 50)
  (list 10 (string-ascii 100))
)

;; Domain ownership claims
(define-map domain-ownership
  (string-ascii 100)
  {
    owner: principal,
    trademark-name: (string-ascii 50),
    verified-at: uint,
    protection-level: uint, ;; 1=basic, 2=standard, 3=premium
    auto-renewal: bool,
    expires-at: uint
  }
)

;; Domain dispute records
(define-map domain-disputes
  uint
  {
    domain-name: (string-ascii 100),
    disputant: principal,
    trademark-name: (string-ascii 50),
    dispute-reason: (string-ascii 200),
    filed-at: uint,
    status: (string-ascii 20), ;; "pending", "resolved", "dismissed"
    evidence: (string-ascii 500),
    resolution: (string-ascii 300)
  }
)

;; Domain monitoring alerts
(define-map domain-monitoring
  (string-ascii 50)
  {
    trademark-owner: principal,
    monitored-domains: (list 20 (string-ascii 100)),
    alert-threshold: uint,
    last-scan: uint,
    active-alerts: uint
  }
)

;; Initiate domain verification process
(define-public (initiate-domain-verification 
  (trademark-name (string-ascii 50))
  (domain-name (string-ascii 100))
  (verification-method (string-ascii 20)))
  (let
    (
      (verification-id (+ (var-get verification-id-nonce) u1))
      (current-block stacks-block-height)
      (expires-at (+ current-block (var-get challenge-duration)))
      (challenge-code (generate-challenge-code verification-id))
      (fee (var-get domain-verification-fee))
    )
    
    ;; Validate trademark ownership
    (asserts! (is-trademark-owner trademark-name tx-sender) err-not-trademark-owner)
    
    ;; Pay verification fee
    (try! (stx-transfer? fee tx-sender (as-contract tx-sender)))
    
    ;; Create verification record
    (map-set domain-verifications verification-id
      {
        trademark-name: trademark-name,
        domain-name: domain-name,
        trademark-owner: tx-sender,
        verification-method: verification-method,
        challenge-code: challenge-code,
        created-at: current-block,
        expires-at: expires-at,
        verified: false,
        verified-at: u0
      }
    )
    
    ;; Update nonce
    (var-set verification-id-nonce verification-id)
    
    (ok { 
      verification-id: verification-id,
      challenge-code: challenge-code,
      expires-at: expires-at
    })
  )
)

;; Complete domain verification
(define-public (complete-domain-verification (verification-id uint))
  (let
    (
      (verification-data (unwrap! (map-get? domain-verifications verification-id) err-domain-not-found))
      (current-block stacks-block-height)
      (trademark-name (get trademark-name verification-data))
      (domain-name (get domain-name verification-data))
    )
    
    ;; Check ownership and timing
    (asserts! (is-eq tx-sender (get trademark-owner verification-data)) err-not-trademark-owner)
    (asserts! (< current-block (get expires-at verification-data)) err-challenge-expired)
    (asserts! (not (get verified verification-data)) err-already-verified)
    
    ;; Verify challenge (simplified - in production would check DNS/file/meta-tag)
    (asserts! (verify-domain-challenge verification-data) err-verification-failed)
    
    ;; Mark as verified
    (map-set domain-verifications verification-id
      (merge verification-data { 
        verified: true,
        verified-at: current-block
      })
    )
    
    ;; Establish domain ownership
    (map-set domain-ownership domain-name
      {
        owner: tx-sender,
        trademark-name: trademark-name,
        verified-at: current-block,
        protection-level: u2, ;; Standard protection
        auto-renewal: false,
        expires-at: (+ current-block u525600) ;; ~1 year
      }
    )
    
    ;; Add domain to trademark's domain list
    (let ((current-domains (default-to (list) (map-get? trademark-domains trademark-name))))
      (map-set trademark-domains trademark-name
        (unwrap-panic (as-max-len? (append current-domains domain-name) u10))
      )
    )
    
    (ok true)
  )
)

;; File domain dispute
(define-public (file-domain-dispute 
  (domain-name (string-ascii 100))
  (trademark-name (string-ascii 50))
  (dispute-reason (string-ascii 200))
  (evidence (string-ascii 500)))
  (let
    (
      (dispute-id (+ (var-get verification-id-nonce) u1))
      (current-block stacks-block-height)
      (dispute-fee (var-get domain-verification-fee))
    )
    
    ;; Validate trademark ownership
    (asserts! (is-trademark-owner trademark-name tx-sender) err-not-trademark-owner)
    
    ;; Pay dispute fee
    (try! (stx-transfer? dispute-fee tx-sender (as-contract tx-sender)))
    
    ;; Create dispute record
    (map-set domain-disputes dispute-id
      {
        domain-name: domain-name,
        disputant: tx-sender,
        trademark-name: trademark-name,
        dispute-reason: dispute-reason,
        filed-at: current-block,
        status: "pending",
        evidence: evidence,
        resolution: ""
      }
    )
    
    (var-set verification-id-nonce dispute-id)
    (ok dispute-id)
  )
)

;; Enable domain monitoring for trademark
(define-public (enable-domain-monitoring 
  (trademark-name (string-ascii 50))
  (domains-to-monitor (list 20 (string-ascii 100))))
  (let
    (
      (monitoring-fee (* (var-get domain-verification-fee) u2))
      (current-block stacks-block-height)
    )
    
    ;; Validate trademark ownership
    (asserts! (is-trademark-owner trademark-name tx-sender) err-not-trademark-owner)
    
    ;; Pay monitoring fee
    (try! (stx-transfer? monitoring-fee tx-sender (as-contract tx-sender)))
    
    ;; Set up monitoring
    (map-set domain-monitoring trademark-name
      {
        trademark-owner: tx-sender,
        monitored-domains: domains-to-monitor,
        alert-threshold: u3, ;; Alert after 3 similar domains detected
        last-scan: current-block,
        active-alerts: u0
      }
    )
    
    (ok true)
  )
)

;; Transfer domain ownership
(define-public (transfer-domain-ownership 
  (domain-name (string-ascii 100))
  (new-owner principal))
  (let
    (
      (domain-data (unwrap! (map-get? domain-ownership domain-name) err-domain-not-found))
      (current-block stacks-block-height)
    )
    
    ;; Check ownership
    (asserts! (is-eq tx-sender (get owner domain-data)) err-not-trademark-owner)
    
    ;; Transfer ownership
    (map-set domain-ownership domain-name
      (merge domain-data { owner: new-owner })
    )
    
    (ok true)
  )
)

;; Renew domain protection
(define-public (renew-domain-protection (domain-name (string-ascii 100)))
  (let
    (
      (domain-data (unwrap! (map-get? domain-ownership domain-name) err-domain-not-found))
      (current-block stacks-block-height)
      (renewal-fee (var-get domain-verification-fee))
    )
    
    ;; Check ownership
    (asserts! (is-eq tx-sender (get owner domain-data)) err-not-trademark-owner)
    
    ;; Pay renewal fee
    (try! (stx-transfer? renewal-fee tx-sender (as-contract tx-sender)))
    
    ;; Extend protection
    (map-set domain-ownership domain-name
      (merge domain-data { 
        expires-at: (+ current-block u525600) ;; Another year
      })
    )
    
    (ok true)
  )
)

;; Private helper functions

;; Generate challenge code for verification
(define-private (generate-challenge-code (verification-id uint))
  (int-to-ascii (+ verification-id u1000000))
)

;; Verify domain challenge (simplified)
(define-private (verify-domain-challenge (verification-data { trademark-name: (string-ascii 50), domain-name: (string-ascii 100), trademark-owner: principal, verification-method: (string-ascii 20), challenge-code: (string-ascii 64), created-at: uint, expires-at: uint, verified: bool, verified-at: uint }))
  ;; Simplified verification - in production would:
  ;; - Check DNS TXT record for challenge code
  ;; - Verify uploaded file at domain/.well-known/brandlock-verification.txt
  ;; - Check meta tag in domain homepage
  true
)

;; Check if user owns trademark (simplified)
(define-private (is-trademark-owner (trademark-name (string-ascii 50)) (user principal))
  ;; Simplified - would check main Brandlock contract for ownership
  true
)

;; Read-only functions

(define-read-only (get-domain-verification (verification-id uint))
  (map-get? domain-verifications verification-id)
)

(define-read-only (get-domain-ownership (domain-name (string-ascii 100)))
  (map-get? domain-ownership domain-name)
)

(define-read-only (get-trademark-domains (trademark-name (string-ascii 50)))
  (default-to (list) (map-get? trademark-domains trademark-name))
)

(define-read-only (get-domain-dispute (dispute-id uint))
  (map-get? domain-disputes dispute-id)
)

(define-read-only (get-domain-monitoring (trademark-name (string-ascii 50)))
  (map-get? domain-monitoring trademark-name)
)

(define-read-only (is-domain-verified (domain-name (string-ascii 100)))
  (is-some (map-get? domain-ownership domain-name))
)

(define-read-only (get-verification-fee)
  (var-get domain-verification-fee)
)

(define-read-only (get-challenge-duration)
  (var-get challenge-duration)
)

;; Check if domain protection is active
(define-read-only (is-domain-protection-active (domain-name (string-ascii 100)))
  (match (map-get? domain-ownership domain-name)
    domain-data (> (get expires-at domain-data) stacks-block-height)
    false
  )
)

;; Get domains expiring soon for a trademark owner
(define-read-only (get-expiring-domains (trademark-owner principal))
  ;; Simplified - would scan all owned domains and return those expiring within 30 days
  (list)
)

;; Calculate domain similarity score (for monitoring)
(define-read-only (calculate-domain-similarity (trademark-name (string-ascii 50)) (domain-name (string-ascii 100)))
  ;; Simplified - would use string similarity algorithms to detect cybersquatting
  u0
)
