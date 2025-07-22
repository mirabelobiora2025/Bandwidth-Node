;; Decentralized Bandwidth Sharing Smart Contract
;; This contract enables users to share and monetize bandwidth in a decentralized manner

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_PROVIDER_NOT_FOUND (err u103))
(define-constant ERR_CONSUMER_NOT_FOUND (err u104))
(define-constant ERR_SESSION_NOT_FOUND (err u105))
(define-constant ERR_SESSION_ALREADY_ACTIVE (err u106))
(define-constant ERR_SESSION_NOT_ACTIVE (err u107))
(define-constant ERR_INVALID_QUALITY_SCORE (err u108))
(define-constant ERR_PROVIDER_ALREADY_EXISTS (err u109))
(define-constant ERR_INVALID_BANDWIDTH (err u110))
(define-constant ERR_PAYMENT_FAILED (err u111))
(define-constant ERR_REPUTATION_TOO_LOW (err u112))

;; Minimum reputation score required to participate
(define-constant MIN_REPUTATION u50)
(define-constant MAX_REPUTATION u100)
(define-constant INITIAL_REPUTATION u75)

;; Fee structure (in basis points, 1% = 100)
(define-constant PLATFORM_FEE_BPS u250) ;; 2.5%

;; Data Variables
(define-data-var total-providers uint u0)
(define-data-var total-consumers uint u0)
(define-data-var total-sessions uint u0)
(define-data-var platform-treasury uint u0)
(define-data-var contract-paused bool false)

;; Data Maps

;; Provider information
(define-map providers
  { provider: principal }
  {
    bandwidth-capacity: uint,     ;; In Mbps
    available-bandwidth: uint,    ;; Current available bandwidth
    price-per-mb: uint,          ;; Price in microSTX per MB
    reputation-score: uint,       ;; 0-100 reputation score
    total-data-served: uint,     ;; Total MB served
    earnings: uint,              ;; Total earnings in microSTX
    is-active: bool,
    location: (string-ascii 50), ;; Geographic location
    uptime-percentage: uint      ;; Uptime percentage (0-10000, where 10000 = 100%)
  }
)

;; Consumer information
(define-map consumers
  { consumer: principal }
  {
    balance: uint,               ;; Prepaid balance in microSTX
    total-consumed: uint,        ;; Total MB consumed
    reputation-score: uint,      ;; 0-100 reputation score
    sessions-count: uint
  }
)

;; Active bandwidth sessions
(define-map sessions
  { session-id: uint }
  {
    provider: principal,
    consumer: principal,
    bandwidth-allocated: uint,   ;; In Mbps
    data-consumed: uint,        ;; In MB
    start-block: uint,
    end-block: (optional uint),
    price-per-mb: uint,
    total-cost: uint,
    is-active: bool,
    quality-score: (optional uint) ;; 1-100, set by consumer after session
  }
)

;; Session mapping for quick lookups
(define-map user-active-sessions
  { user: principal }
  { session-id: uint }
)

;; Provider performance metrics
(define-map provider-metrics
  { provider: principal, period: uint } ;; period = block-height / 1000 for weekly metrics
  {
    data-served: uint,
    average-quality: uint,
    session-count: uint,
    uptime-blocks: uint
  }
)

;; Read-only functions

;; Get provider information
(define-read-only (get-provider (provider principal))
  (map-get? providers { provider: provider })
)

;; Get consumer information
(define-read-only (get-consumer (consumer principal))
  (map-get? consumers { consumer: consumer })
)

;; Get session information
(define-read-only (get-session (session-id uint))
  (map-get? sessions { session-id: session-id })
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-providers: (var-get total-providers),
    total-consumers: (var-get total-consumers),
    total-sessions: (var-get total-sessions),
    platform-treasury: (var-get platform-treasury),
    contract-paused: (var-get contract-paused)
  }
)

;; Get user's active session
(define-read-only (get-user-active-session (user principal))
  (map-get? user-active-sessions { user: user })
)

;; Calculate session cost
(define-read-only (calculate-session-cost (data-mb uint) (price-per-mb uint))
  (* data-mb price-per-mb)
)

;; Get platform fee for amount
(define-read-only (get-platform-fee (amount uint))
  (/ (* amount PLATFORM_FEE_BPS) u10000)
)

;; Get provider metrics for a period
(define-read-only (get-provider-metrics (provider principal) (period uint))
  (map-get? provider-metrics { provider: provider, period: period })
)

;; Check if provider can serve bandwidth
(define-read-only (can-provider-serve (provider principal) (bandwidth-required uint))
  (match (map-get? providers { provider: provider })
    provider-data
    (and 
      (get is-active provider-data)
      (>= (get available-bandwidth provider-data) bandwidth-required)
      (>= (get reputation-score provider-data) MIN_REPUTATION)
    )
    false
  )
)

;; Public functions

;; Register as a bandwidth provider
(define-public (register-provider 
  (bandwidth-capacity uint) 
  (price-per-mb uint) 
  (location (string-ascii 50)))
  (let (
    (provider tx-sender)
  )
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (> bandwidth-capacity u0) ERR_INVALID_BANDWIDTH)
    (asserts! (> price-per-mb u0) ERR_INVALID_AMOUNT)
    (asserts! (is-none (map-get? providers { provider: provider })) ERR_PROVIDER_ALREADY_EXISTS)
    
    (map-set providers
      { provider: provider }
      {
        bandwidth-capacity: bandwidth-capacity,
        available-bandwidth: bandwidth-capacity,
        price-per-mb: price-per-mb,
        reputation-score: INITIAL_REPUTATION,
        total-data-served: u0,
        earnings: u0,
        is-active: true,
        location: location,
        uptime-percentage: u10000
      }
    )
    
    (var-set total-providers (+ (var-get total-providers) u1))
    (ok true)
  )
)

;; Register as a consumer and add balance
(define-public (register-consumer (initial-balance uint))
  (let (
    (consumer tx-sender)
  )
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (> initial-balance u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer STX to contract as balance
    (try! (stx-transfer? initial-balance tx-sender (as-contract tx-sender)))
    
    (map-set consumers
      { consumer: consumer }
      {
        balance: initial-balance,
        total-consumed: u0,
        reputation-score: INITIAL_REPUTATION,
        sessions-count: u0
      }
    )
    
    (var-set total-consumers (+ (var-get total-consumers) u1))
    (ok true)
  )
)

;; Add balance to consumer account
(define-public (add-balance (amount uint))
  (let (
    (consumer tx-sender)
    (consumer-data (unwrap! (map-get? consumers { consumer: consumer }) ERR_CONSUMER_NOT_FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set consumers
      { consumer: consumer }
      (merge consumer-data { balance: (+ (get balance consumer-data) amount) })
    )
    
    (ok true)
  )
)

;; Start a bandwidth session
(define-public (start-session (provider principal) (bandwidth-required uint))
  (let (
    (consumer tx-sender)
    (session-id (+ (var-get total-sessions) u1))
    (provider-data (unwrap! (map-get? providers { provider: provider }) ERR_PROVIDER_NOT_FOUND))
    (consumer-data (unwrap! (map-get? consumers { consumer: consumer }) ERR_CONSUMER_NOT_FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (> bandwidth-required u0) ERR_INVALID_BANDWIDTH)
    (asserts! (can-provider-serve provider bandwidth-required) ERR_INVALID_BANDWIDTH)
    (asserts! (>= (get reputation-score consumer-data) MIN_REPUTATION) ERR_REPUTATION_TOO_LOW)
    (asserts! (is-none (map-get? user-active-sessions { user: consumer })) ERR_SESSION_ALREADY_ACTIVE)
    
    ;; Update provider's available bandwidth
    (map-set providers
      { provider: provider }
      (merge provider-data 
        { available-bandwidth: (- (get available-bandwidth provider-data) bandwidth-required) }
      )
    )
    
    ;; Create session
    (map-set sessions
      { session-id: session-id }
      {
        provider: provider,
        consumer: consumer,
        bandwidth-allocated: bandwidth-required,
        data-consumed: u0,
        start-block: block-height,
        end-block: none,
        price-per-mb: (get price-per-mb provider-data),
        total-cost: u0,
        is-active: true,
        quality-score: none
      }
    )
    
    ;; Track active session
    (map-set user-active-sessions
      { user: consumer }
      { session-id: session-id }
    )
    
    (var-set total-sessions session-id)
    (ok session-id)
  )
)

;; End session and process payment
(define-public (end-session (session-id uint) (data-consumed uint))
  (let (
    (session-data (unwrap! (map-get? sessions { session-id: session-id }) ERR_SESSION_NOT_FOUND))
    (provider (get provider session-data))
    (consumer (get consumer session-data))
    (provider-data (unwrap! (map-get? providers { provider: provider }) ERR_PROVIDER_NOT_FOUND))
    (consumer-data (unwrap! (map-get? consumers { consumer: consumer }) ERR_CONSUMER_NOT_FOUND))
    (total-cost (calculate-session-cost data-consumed (get price-per-mb session-data)))
    (platform-fee (get-platform-fee total-cost))
    (provider-payment (- total-cost platform-fee))
  )
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (or (is-eq tx-sender provider) (is-eq tx-sender consumer)) ERR_UNAUTHORIZED)
    (asserts! (get is-active session-data) ERR_SESSION_NOT_ACTIVE)
    (asserts! (>= (get balance consumer-data) total-cost) ERR_INSUFFICIENT_BALANCE)
    
    ;; Process payment
    (try! (as-contract (stx-transfer? provider-payment tx-sender provider)))
    
    ;; Update consumer balance
    (map-set consumers
      { consumer: consumer }
      (merge consumer-data {
        balance: (- (get balance consumer-data) total-cost),
        total-consumed: (+ (get total-consumed consumer-data) data-consumed),
        sessions-count: (+ (get sessions-count consumer-data) u1)
      })
    )
    
    ;; Update provider data
    (map-set providers
      { provider: provider }
      (merge provider-data {
        available-bandwidth: (+ (get available-bandwidth provider-data) (get bandwidth-allocated session-data)),
        total-data-served: (+ (get total-data-served provider-data) data-consumed),
        earnings: (+ (get earnings provider-data) provider-payment)
      })
    )
    
    ;; Update session
    (map-set sessions
      { session-id: session-id }
      (merge session-data {
        data-consumed: data-consumed,
        end-block: (some block-height),
        total-cost: total-cost,
        is-active: false
      })
    )
    
    ;; Remove active session tracking
    (map-delete user-active-sessions { user: consumer })
    
    ;; Update platform treasury
    (var-set platform-treasury (+ (var-get platform-treasury) platform-fee))
    
    ;; Update provider metrics
    (update-provider-metrics provider data-consumed)
    
    (ok total-cost)
  )
)

;; Rate session quality (consumer only)
(define-public (rate-session (session-id uint) (quality-score uint))
  (let (
    (session-data (unwrap! (map-get? sessions { session-id: session-id }) ERR_SESSION_NOT_FOUND))
    (provider (get provider session-data))
    (provider-data (unwrap! (map-get? providers { provider: provider }) ERR_PROVIDER_NOT_FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (is-eq tx-sender (get consumer session-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get is-active session-data)) ERR_SESSION_NOT_ACTIVE)
    (asserts! (and (>= quality-score u1) (<= quality-score u100)) ERR_INVALID_QUALITY_SCORE)
    (asserts! (is-none (get quality-score session-data)) ERR_INVALID_QUALITY_SCORE)
    
    ;; Update session with quality score
    (map-set sessions
      { session-id: session-id }
      (merge session-data { quality-score: (some quality-score) })
    )
    
    ;; Update provider reputation based on quality score
    (update-provider-reputation provider quality-score)
    
    (ok true)
  )
)

;; Update provider settings
(define-public (update-provider-settings 
  (new-price-per-mb (optional uint))
  (new-capacity (optional uint))
  (active-status (optional bool)))
  (let (
    (provider tx-sender)
    (provider-data (unwrap! (map-get? providers { provider: provider }) ERR_PROVIDER_NOT_FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    
    (map-set providers
      { provider: provider }
      (merge provider-data {
        price-per-mb: (default-to (get price-per-mb provider-data) new-price-per-mb),
        bandwidth-capacity: (default-to (get bandwidth-capacity provider-data) new-capacity),
        available-bandwidth: (default-to (get available-bandwidth provider-data) new-capacity),
        is-active: (default-to (get is-active provider-data) active-status)
      })
    )
    
    (ok true)
  )
)

;; Withdraw earnings (providers only)
(define-public (withdraw-earnings (amount uint))
  (let (
    (provider tx-sender)
    (provider-data (unwrap! (map-get? providers { provider: provider }) ERR_PROVIDER_NOT_FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (get earnings provider-data) amount) ERR_INSUFFICIENT_BALANCE)
    
    ;; Transfer earnings to provider
    (try! (as-contract (stx-transfer? amount tx-sender provider)))
    
    ;; Update provider earnings
    (map-set providers
      { provider: provider }
      (merge provider-data { earnings: (- (get earnings provider-data) amount) })
    )
    
    (ok true)
  )
)

;; Emergency functions (contract owner only)

;; Pause/unpause contract
(define-public (set-contract-pause (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-paused paused)
    (ok true)
  )
)

;; Withdraw platform fees (contract owner only)
(define-public (withdraw-platform-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (>= (var-get platform-treasury) amount) ERR_INSUFFICIENT_BALANCE)
    
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
    (var-set platform-treasury (- (var-get platform-treasury) amount))
    
    (ok true)
  )
)

;; Private functions

;; Helper function to get minimum of two values
(define-private (min-uint (a uint) (b uint))
  (if (< a b) a b)
)

;; Update provider reputation based on quality scores
(define-private (update-provider-reputation (provider principal) (quality-score uint))
  (match (map-get? providers { provider: provider })
    provider-data
    (let (
      (current-reputation (get reputation-score provider-data))
      ;; Simple weighted average: 90% current + 10% new score
      (new-reputation (/ (+ (* current-reputation u90) (* quality-score u10)) u100))
    )
      (map-set providers
        { provider: provider }
        (merge provider-data { reputation-score: (min-uint new-reputation MAX_REPUTATION) })
      )
      true
    )
    false
  )
)

;; Update provider metrics for analytics
(define-private (update-provider-metrics (provider principal) (data-served uint))
  (let (
    (current-period (/ block-height u1000))
    (existing-metrics (default-to 
      { data-served: u0, average-quality: u0, session-count: u0, uptime-blocks: u0 }
      (map-get? provider-metrics { provider: provider, period: current-period })
    ))
  )
    (map-set provider-metrics
      { provider: provider, period: current-period }
      (merge existing-metrics {
        data-served: (+ (get data-served existing-metrics) data-served),
        session-count: (+ (get session-count existing-metrics) u1)
      })
    )
    true
  )
)