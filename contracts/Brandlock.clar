(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_TRADEMARK_EXISTS (err u101))
(define-constant ERR_TRADEMARK_NOT_FOUND (err u102))
(define-constant ERR_INVALID_NAME (err u103))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u104))
(define-constant ERR_CLAIM_EXPIRED (err u105))
(define-constant ERR_NOT_OWNER (err u106))

(define-data-var registration-fee uint u1000000)
(define-data-var renewal-fee uint u500000)
(define-data-var claim-duration uint u52560)

(define-map trademarks
  { name: (string-ascii 50) }
  {
    owner: principal,
    registered-at: uint,
    expires-at: uint,
    category: (string-ascii 30),
    description: (string-ascii 200),
    active: bool
  }
)

(define-map user-trademarks
  { user: principal }
  { trademark-count: uint }
)

(define-map trademark-transfers
  { name: (string-ascii 50) }
  {
    from: principal,
    to: principal,
    initiated-at: uint,
    completed: bool
  }
)

(define-public (register-trademark (name (string-ascii 50)) (category (string-ascii 30)) (description (string-ascii 200)))
  (let (
    (current-block stacks-block-height)
    (fee (var-get registration-fee))
    (duration (var-get claim-duration))
  )
    (asserts! (> (len name) u0) ERR_INVALID_NAME)
    (asserts! (<= (len name) u50) ERR_INVALID_NAME)
    (asserts! (is-none (map-get? trademarks { name: name })) ERR_TRADEMARK_EXISTS)
    
    (try! (stx-transfer? fee tx-sender CONTRACT_OWNER))
    
    (map-set trademarks
      { name: name }
      {
        owner: tx-sender,
        registered-at: current-block,
        expires-at: (+ current-block duration),
        category: category,
        description: description,
        active: true
      }
    )
    
    (map-set user-trademarks
      { user: tx-sender }
      { trademark-count: (+ (get-user-trademark-count tx-sender) u1) }
    )
    
    (ok true)
  )
)

(define-public (renew-trademark (name (string-ascii 50)))
  (let (
    (trademark-data (unwrap! (map-get? trademarks { name: name }) ERR_TRADEMARK_NOT_FOUND))
    (current-block stacks-block-height)
    (fee (var-get renewal-fee))
    (duration (var-get claim-duration))
  )
    (asserts! (is-eq (get owner trademark-data) tx-sender) ERR_NOT_OWNER)
    (asserts! (get active trademark-data) ERR_TRADEMARK_NOT_FOUND)
    
    (try! (stx-transfer? fee tx-sender CONTRACT_OWNER))
    
    (map-set trademarks
      { name: name }
      (merge trademark-data { expires-at: (+ current-block duration) })
    )
    
    (ok true)
  )
)

(define-public (transfer-trademark (name (string-ascii 50)) (new-owner principal))
  (let (
    (trademark-data (unwrap! (map-get? trademarks { name: name }) ERR_TRADEMARK_NOT_FOUND))
    (current-block stacks-block-height)
  )
    (asserts! (is-eq (get owner trademark-data) tx-sender) ERR_NOT_OWNER)
    (asserts! (get active trademark-data) ERR_TRADEMARK_NOT_FOUND)
    (asserts! (< current-block (get expires-at trademark-data)) ERR_CLAIM_EXPIRED)
    
    (map-set trademarks
      { name: name }
      (merge trademark-data { owner: new-owner })
    )
    
    (map-set user-trademarks
      { user: tx-sender }
      { trademark-count: (- (get-user-trademark-count tx-sender) u1) }
    )
    
    (map-set user-trademarks
      { user: new-owner }
      { trademark-count: (+ (get-user-trademark-count new-owner) u1) }
    )
    
    (map-set trademark-transfers
      { name: name }
      {
        from: tx-sender,
        to: new-owner,
        initiated-at: current-block,
        completed: true
      }
    )
    
    (ok true)
  )
)

(define-public (deactivate-trademark (name (string-ascii 50)))
  (let (
    (trademark-data (unwrap! (map-get? trademarks { name: name }) ERR_TRADEMARK_NOT_FOUND))
  )
    (asserts! (is-eq (get owner trademark-data) tx-sender) ERR_NOT_OWNER)
    (asserts! (get active trademark-data) ERR_TRADEMARK_NOT_FOUND)
    
    (map-set trademarks
      { name: name }
      (merge trademark-data { active: false })
    )
    
    (map-set user-trademarks
      { user: tx-sender }
      { trademark-count: (- (get-user-trademark-count tx-sender) u1) }
    )
    
    (ok true)
  )
)

(define-public (update-registration-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set registration-fee new-fee)
    (ok true)
  )
)

(define-public (update-renewal-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set renewal-fee new-fee)
    (ok true)
  )
)

(define-public (update-claim-duration (new-duration uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set claim-duration new-duration)
    (ok true)
  )
)

(define-read-only (get-trademark (name (string-ascii 50)))
  (map-get? trademarks { name: name })
)

(define-read-only (is-trademark-available (name (string-ascii 50)))
  (let (
    (trademark-data (map-get? trademarks { name: name }))
  )
    (match trademark-data
      data (or 
        (not (get active data))
        (>= stacks-block-height (get expires-at data))
      )
      true
    )
  )
)

(define-read-only (is-trademark-expired (name (string-ascii 50)))
  (let (
    (trademark-data (map-get? trademarks { name: name }))
  )
    (match trademark-data
      data (>= stacks-block-height (get expires-at data))
      false
    )
  )
)

(define-read-only (get-trademark-owner (name (string-ascii 50)))
  (match (map-get? trademarks { name: name })
    data (some (get owner data))
    none
  )
)

(define-read-only (get-user-trademark-count (user principal))
  (default-to u0 (get trademark-count (map-get? user-trademarks { user: user })))
)

(define-read-only (get-registration-fee)
  (var-get registration-fee)
)

(define-read-only (get-renewal-fee)
  (var-get renewal-fee)
)

(define-read-only (get-claim-duration)
  (var-get claim-duration)
)

(define-read-only (get-trademark-transfer (name (string-ascii 50)))
  (map-get? trademark-transfers { name: name })
)

(define-read-only (validate-trademark-name (name (string-ascii 50)))
  (and 
    (> (len name) u0)
    (<= (len name) u50)
  )
)

(define-read-only (get-contract-info)
  {
    owner: CONTRACT_OWNER,
    registration-fee: (var-get registration-fee),
    renewal-fee: (var-get renewal-fee),
    claim-duration: (var-get claim-duration)
  }
)