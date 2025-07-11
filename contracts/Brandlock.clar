(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_TRADEMARK_EXISTS (err u101))
(define-constant ERR_TRADEMARK_NOT_FOUND (err u102))
(define-constant ERR_INVALID_NAME (err u103))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u104))
(define-constant ERR_CLAIM_EXPIRED (err u105))
(define-constant ERR_NOT_OWNER (err u106))
(define-constant ERR_LICENSE_NOT_FOUND (err u107))
(define-constant ERR_LICENSE_EXPIRED (err u108))
(define-constant ERR_INSUFFICIENT_ROYALTY (err u109))
(define-constant ERR_LICENSE_ALREADY_EXISTS (err u110))
(define-constant ERR_INVALID_LICENSE_TERMS (err u111))
(define-constant ERR_UNAUTHORIZED_LICENSEE (err u112))
(define-constant ERR_ROYALTY_OVERDUE (err u113))

(define-data-var registration-fee uint u1000000)
(define-data-var renewal-fee uint u500000)
(define-data-var claim-duration uint u52560)
(define-data-var max-license-duration uint u262800)
(define-data-var min-royalty-rate uint u100)

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

(define-map trademark-licenses
  { trademark: (string-ascii 50), licensee: principal }
  {
    licensor: principal,
    license-fee: uint,
    royalty-rate: uint,
    created-at: uint,
    expires-at: uint,
    usage-limit: uint,
    usage-count: uint,
    active: bool,
    exclusive: bool,
    territory: (string-ascii 50),
    purpose: (string-ascii 100),
    last-royalty-payment: uint,
    total-royalties-paid: uint
  }
)

(define-map license-revenue
  { licensor: principal }
  {
    total-earned: uint,
    active-licenses: uint,
    withdrawn: uint
  }
)

(define-map licensee-status
  { licensee: principal, trademark: (string-ascii 50) }
  {
    compliance-score: uint,
    violations: uint,
    last-payment: uint,
    next-payment-due: uint
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

(define-public (create-license (trademark (string-ascii 50)) (licensee principal) (license-fee uint) (royalty-rate uint) (duration uint) (usage-limit uint) (exclusive bool) (territory (string-ascii 50)) (purpose (string-ascii 100)))
  (let (
    (trademark-data (unwrap! (map-get? trademarks { name: trademark }) ERR_TRADEMARK_NOT_FOUND))
    (current-block stacks-block-height)
    (max-duration (var-get max-license-duration))
    (min-royalty (var-get min-royalty-rate))
    (license-key { trademark: trademark, licensee: licensee })
  )
    (asserts! (is-eq (get owner trademark-data) tx-sender) ERR_NOT_OWNER)
    (asserts! (get active trademark-data) ERR_TRADEMARK_NOT_FOUND)
    (asserts! (< current-block (get expires-at trademark-data)) ERR_CLAIM_EXPIRED)
    (asserts! (is-none (map-get? trademark-licenses license-key)) ERR_LICENSE_ALREADY_EXISTS)
    (asserts! (> duration u0) ERR_INVALID_LICENSE_TERMS)
    (asserts! (<= duration max-duration) ERR_INVALID_LICENSE_TERMS)
    (asserts! (>= royalty-rate min-royalty) ERR_INVALID_LICENSE_TERMS)
    (asserts! (> usage-limit u0) ERR_INVALID_LICENSE_TERMS)
    (asserts! (> license-fee u0) ERR_INVALID_LICENSE_TERMS)
    
    (try! (stx-transfer? license-fee licensee tx-sender))
    
    (map-set trademark-licenses
      license-key
      {
        licensor: tx-sender,
        license-fee: license-fee,
        royalty-rate: royalty-rate,
        created-at: current-block,
        expires-at: (+ current-block duration),
        usage-limit: usage-limit,
        usage-count: u0,
        active: true,
        exclusive: exclusive,
        territory: territory,
        purpose: purpose,
        last-royalty-payment: current-block,
        total-royalties-paid: u0
      }
    )
    
    (map-set license-revenue
      { licensor: tx-sender }
      {
        total-earned: (+ (get-licensor-total-earned tx-sender) license-fee),
        active-licenses: (+ (get-licensor-active-licenses tx-sender) u1),
        withdrawn: (get-licensor-withdrawn tx-sender)
      }
    )
    
    (map-set licensee-status
      { licensee: licensee, trademark: trademark }
      {
        compliance-score: u100,
        violations: u0,
        last-payment: current-block,
        next-payment-due: (+ current-block u2160)
      }
    )
    
    (ok true)
  )
)

(define-public (pay-royalty (trademark (string-ascii 50)) (usage-count uint))
  (let (
    (license-key { trademark: trademark, licensee: tx-sender })
    (license-data (unwrap! (map-get? trademark-licenses license-key) ERR_LICENSE_NOT_FOUND))
    (current-block stacks-block-height)
    (royalty-amount (/ (* usage-count (get royalty-rate license-data)) u10000))
    (new-usage-count (+ (get usage-count license-data) usage-count))
  )
    (asserts! (get active license-data) ERR_LICENSE_NOT_FOUND)
    (asserts! (< current-block (get expires-at license-data)) ERR_LICENSE_EXPIRED)
    (asserts! (<= new-usage-count (get usage-limit license-data)) ERR_INVALID_LICENSE_TERMS)
    (asserts! (> royalty-amount u0) ERR_INSUFFICIENT_ROYALTY)
    
    (try! (stx-transfer? royalty-amount tx-sender (get licensor license-data)))
    
    (map-set trademark-licenses
      license-key
      (merge license-data {
        usage-count: new-usage-count,
        last-royalty-payment: current-block,
        total-royalties-paid: (+ (get total-royalties-paid license-data) royalty-amount)
      })
    )
    
    (map-set license-revenue
      { licensor: (get licensor license-data) }
      {
        total-earned: (+ (get-licensor-total-earned (get licensor license-data)) royalty-amount),
        active-licenses: (get-licensor-active-licenses (get licensor license-data)),
        withdrawn: (get-licensor-withdrawn (get licensor license-data))
      }
    )
    
    (map-set licensee-status
      { licensee: tx-sender, trademark: trademark }
      {
        compliance-score: (if (<= (+ (get-licensee-compliance-score tx-sender trademark) u5) u100) (+ (get-licensee-compliance-score tx-sender trademark) u5) u100),
        violations: (get-licensee-violations tx-sender trademark),
        last-payment: current-block,
        next-payment-due: (+ current-block u2160)
      }
    )
    
    (ok true)
  )
)

(define-public (revoke-license (trademark (string-ascii 50)) (licensee principal))
  (let (
    (trademark-data (unwrap! (map-get? trademarks { name: trademark }) ERR_TRADEMARK_NOT_FOUND))
    (license-key { trademark: trademark, licensee: licensee })
    (license-data (unwrap! (map-get? trademark-licenses license-key) ERR_LICENSE_NOT_FOUND))
  )
    (asserts! (is-eq (get owner trademark-data) tx-sender) ERR_NOT_OWNER)
    (asserts! (get active license-data) ERR_LICENSE_NOT_FOUND)
    
    (map-set trademark-licenses
      license-key
      (merge license-data { active: false })
    )
    
    (map-set license-revenue
      { licensor: tx-sender }
      {
        total-earned: (get-licensor-total-earned tx-sender),
        active-licenses: (- (get-licensor-active-licenses tx-sender) u1),
        withdrawn: (get-licensor-withdrawn tx-sender)
      }
    )
    
    (ok true)
  )
)

(define-public (extend-license (trademark (string-ascii 50)) (additional-duration uint) (extension-fee uint))
  (let (
    (license-key { trademark: trademark, licensee: tx-sender })
    (license-data (unwrap! (map-get? trademark-licenses license-key) ERR_LICENSE_NOT_FOUND))
    (current-block stacks-block-height)
    (max-duration (var-get max-license-duration))
    (new-expires-at (+ (get expires-at license-data) additional-duration))
  )
    (asserts! (get active license-data) ERR_LICENSE_NOT_FOUND)
    (asserts! (< current-block (get expires-at license-data)) ERR_LICENSE_EXPIRED)
    (asserts! (> additional-duration u0) ERR_INVALID_LICENSE_TERMS)
    (asserts! (<= additional-duration max-duration) ERR_INVALID_LICENSE_TERMS)
    (asserts! (> extension-fee u0) ERR_INVALID_LICENSE_TERMS)
    
    (try! (stx-transfer? extension-fee tx-sender (get licensor license-data)))
    
    (map-set trademark-licenses
      license-key
      (merge license-data { expires-at: new-expires-at })
    )
    
    (map-set license-revenue
      { licensor: (get licensor license-data) }
      {
        total-earned: (+ (get-licensor-total-earned (get licensor license-data)) extension-fee),
        active-licenses: (get-licensor-active-licenses (get licensor license-data)),
        withdrawn: (get-licensor-withdrawn (get licensor license-data))
      }
    )
    
    (ok true)
  )
)

(define-public (withdraw-license-revenue (amount uint))
  (let (
    (available-balance (- (get-licensor-total-earned tx-sender) (get-licensor-withdrawn tx-sender)))
  )
    (asserts! (<= amount available-balance) ERR_INSUFFICIENT_PAYMENT)
    (asserts! (> amount u0) ERR_INSUFFICIENT_PAYMENT)
    
    (map-set license-revenue
      { licensor: tx-sender }
      {
        total-earned: (get-licensor-total-earned tx-sender),
        active-licenses: (get-licensor-active-licenses tx-sender),
        withdrawn: (+ (get-licensor-withdrawn tx-sender) amount)
      }
    )
    
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

(define-read-only (get-license (trademark (string-ascii 50)) (licensee principal))
  (map-get? trademark-licenses { trademark: trademark, licensee: licensee })
)

(define-read-only (is-license-active (trademark (string-ascii 50)) (licensee principal))
  (let (
    (license-data (map-get? trademark-licenses { trademark: trademark, licensee: licensee }))
    (current-block stacks-block-height)
  )
    (match license-data
      data (and 
        (get active data)
        (< current-block (get expires-at data))
      )
      false
    )
  )
)

(define-read-only (get-licensee-compliance-score (licensee principal) (trademark (string-ascii 50)))
  (default-to u0 (get compliance-score (map-get? licensee-status { licensee: licensee, trademark: trademark })))
)

(define-read-only (get-licensee-violations (licensee principal) (trademark (string-ascii 50)))
  (default-to u0 (get violations (map-get? licensee-status { licensee: licensee, trademark: trademark })))
)

(define-read-only (get-licensor-total-earned (licensor principal))
  (default-to u0 (get total-earned (map-get? license-revenue { licensor: licensor })))
)

(define-read-only (get-licensor-active-licenses (licensor principal))
  (default-to u0 (get active-licenses (map-get? license-revenue { licensor: licensor })))
)

(define-read-only (get-licensor-withdrawn (licensor principal))
  (default-to u0 (get withdrawn (map-get? license-revenue { licensor: licensor })))
)

(define-read-only (get-licensor-available-balance (licensor principal))
  (- (get-licensor-total-earned licensor) (get-licensor-withdrawn licensor))
)

(define-read-only (calculate-royalty-amount (trademark (string-ascii 50)) (licensee principal) (usage-count uint))
  (let (
    (license-data (map-get? trademark-licenses { trademark: trademark, licensee: licensee }))
  )
    (match license-data
      data (/ (* usage-count (get royalty-rate data)) u10000)
      u0
    )
  )
)

(define-read-only (get-license-usage-remaining (trademark (string-ascii 50)) (licensee principal))
  (let (
    (license-data (map-get? trademark-licenses { trademark: trademark, licensee: licensee }))
  )
    (match license-data
      data (- (get usage-limit data) (get usage-count data))
      u0
    )
  )
)

(define-read-only (is-license-expired (trademark (string-ascii 50)) (licensee principal))
  (let (
    (license-data (map-get? trademark-licenses { trademark: trademark, licensee: licensee }))
    (current-block stacks-block-height)
  )
    (match license-data
      data (>= current-block (get expires-at data))
      false
    )
  )
)

(define-read-only (get-license-revenue-info (licensor principal))
  (map-get? license-revenue { licensor: licensor })
)

(define-read-only (get-licensee-status-info (licensee principal) (trademark (string-ascii 50)))
  (map-get? licensee-status { licensee: licensee, trademark: trademark })
)

(define-read-only (get-max-license-duration)
  (var-get max-license-duration)
)

(define-read-only (get-min-royalty-rate)
  (var-get min-royalty-rate)
)