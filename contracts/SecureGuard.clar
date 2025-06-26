;; SecureGuard Insurance Protocol
;; A decentralized insurance protocol for protecting digital assets

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-funds (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-policy-expired (err u105))
(define-constant err-claim-already-processed (err u106))

;; Define data variables
(define-data-var next-policy-id uint u1)
(define-data-var total-premium-pool uint u0)
(define-data-var protocol-fee-rate uint u500) ;; 5% in basis points

;; Define data maps
(define-map policies
  { policy-id: uint }
  {
    owner: principal,
    coverage-amount: uint,
    premium-paid: uint,
    start-block: uint,
    duration-blocks: uint,
    is-active: bool,
    asset-type: (string-ascii 50)
  }
)

(define-map claims
  { claim-id: uint }
  {
    policy-id: uint,
    claimant: principal,
    amount: uint,
    status: (string-ascii 20),
    submitted-block: uint,
    processed-block: (optional uint)
  }
)

(define-map user-policies
  { user: principal }
  { policy-ids: (list 50 uint) }
)

;; Define private functions
(define-private (is-policy-active (policy-id uint))
  (match (map-get? policies { policy-id: policy-id })
    policy-data (and 
      (get is-active policy-data)
      (< stacks-block-height (+ (get start-block policy-data) (get duration-blocks policy-data)))
    )
    false
  )
)

(define-private (calculate-premium (coverage-amount uint) (duration-blocks uint))
  (let ((base-rate u100)) ;; 1% base rate in basis points
    (/ (* coverage-amount base-rate duration-blocks) (* u10000 u52560)) ;; Approximate blocks per year
  )
)

;; Public functions
(define-public (create-policy (coverage-amount uint) (duration-blocks uint) (asset-type (string-ascii 50)))
  (begin
    (asserts! (and (> coverage-amount u0) (> duration-blocks u0) (>= (len asset-type) u1)) err-invalid-amount)
    (let (
      (policy-id (var-get next-policy-id))
      (premium (calculate-premium coverage-amount duration-blocks))
      (current-user-policies (default-to { policy-ids: (list) } (map-get? user-policies { user: tx-sender })))
    )
      (asserts! (>= (stx-get-balance tx-sender) premium) err-insufficient-funds)
    
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    
    (map-set policies
      { policy-id: policy-id }
      {
        owner: tx-sender,
        coverage-amount: coverage-amount,
        premium-paid: premium,
        start-block: stacks-block-height,
        duration-blocks: duration-blocks,
        is-active: true,
        asset-type: asset-type
      }
    )
    
    (map-set user-policies
      { user: tx-sender }
      { policy-ids: (unwrap! (as-max-len? (append (get policy-ids current-user-policies) policy-id) u50) err-invalid-amount) }
    )
    
    (var-set next-policy-id (+ policy-id u1))
    (var-set total-premium-pool (+ (var-get total-premium-pool) premium))
    
    (ok policy-id)
    )
  )
)

(define-public (submit-claim (policy-id uint) (claim-amount uint))
  (begin
    (asserts! (> policy-id u0) err-invalid-amount)
    (let (
      (policy-data (unwrap! (map-get? policies { policy-id: policy-id }) err-not-found))
      (claim-id (+ policy-id (* stacks-block-height u1000000))) ;; Simple claim ID generation
    )
      (asserts! (is-eq (get owner policy-data) tx-sender) err-owner-only)
      (asserts! (is-policy-active policy-id) err-policy-expired)
      (asserts! (<= claim-amount (get coverage-amount policy-data)) err-invalid-amount)
      
      (map-set claims
        { claim-id: claim-id }
        {
          policy-id: policy-id,
          claimant: tx-sender,
          amount: claim-amount,
          status: "pending",
          submitted-block: stacks-block-height,
          processed-block: none
        }
      )
      
      (ok claim-id)
    )
  )
)

(define-public (process-claim (claim-id uint) (approved bool))
  (begin
    (asserts! (> claim-id u0) err-invalid-amount)
    (let (
      (claim-data (unwrap! (map-get? claims { claim-id: claim-id }) err-not-found))
      (policy-data (unwrap! (map-get? policies { policy-id: (get policy-id claim-data) }) err-not-found))
    )
      (asserts! (is-eq contract-owner tx-sender) err-owner-only)
      (asserts! (is-eq (get status claim-data) "pending") err-claim-already-processed)
      
      (if approved
        (begin
          (try! (as-contract (stx-transfer? (get amount claim-data) tx-sender (get claimant claim-data))))
          (map-set claims
            { claim-id: claim-id }
            (merge claim-data { status: "approved", processed-block: (some stacks-block-height) })
          )
          (ok "claim-approved")
        )
        (begin
          (map-set claims
            { claim-id: claim-id }
            (merge claim-data { status: "rejected", processed-block: (some stacks-block-height) })
          )
          (ok "claim-rejected")
        )
      )
    )
  )
)

(define-public (cancel-policy (policy-id uint))
  (begin
    (asserts! (> policy-id u0) err-invalid-amount)
    (let (
      (policy-data (unwrap! (map-get? policies { policy-id: policy-id }) err-not-found))
    )
      (asserts! (is-eq (get owner policy-data) tx-sender) err-owner-only)
      (asserts! (get is-active policy-data) err-not-found)
      
      (map-set policies
        { policy-id: policy-id }
        (merge policy-data { is-active: false })
      )
      
      (ok true)
    )
  )
)

;; Read-only functions
(define-read-only (get-policy (policy-id uint))
  (map-get? policies { policy-id: policy-id })
)

(define-read-only (get-claim (claim-id uint))
  (map-get? claims { claim-id: claim-id })
)

(define-read-only (get-user-policies (user principal))
  (map-get? user-policies { user: user })
)

(define-read-only (get-premium-estimate (coverage-amount uint) (duration-blocks uint))
  (calculate-premium coverage-amount duration-blocks)
)

(define-read-only (get-total-premium-pool)
  (var-get total-premium-pool)
)

(define-read-only (is-policy-valid (policy-id uint))
  (is-policy-active policy-id)
)