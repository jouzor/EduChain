;; EduChain - Educational Crowdfunding Platform on Stacks Blockchain
;; A smart contract for managing educational initiatives and scholarship programs

;; Constants
(define-constant DEPLOYER tx-sender)
(define-constant PLATFORM-FEE-PERCENTAGE u5)
(define-constant MINIMUM-FUNDING-AMOUNT u10000000) ;; 10 STX in microSTX

;; Data Variables
(define-data-var next-initiative-id uint u0)
(define-data-var platform-balance uint u0)
(define-data-var total-funded uint u0)

;; Maps
(define-map initiatives
  { initiative-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    target-amount: uint,
    current-amount: uint,
    deadline: uint,
    status: (string-ascii 20),
    created-at: uint,
    beneficiaries: uint
  }
)

(define-map contributions
  { contributor: principal, initiative-id: uint }
  {
    amount: uint,
    contributed-at: uint,
    withdrawn: bool
  }
)

;; Create a new educational initiative
(define-public (create-initiative
  (title (string-ascii 100))
  (description (string-ascii 500))
  (category (string-ascii 50))
  (target-amount uint)
  (duration-blocks uint)
  (beneficiaries uint)
)
  (let
    (
      (initiative-id (var-get next-initiative-id))
      (deadline (+ burn-block-height duration-blocks))
    )
    (asserts! (> target-amount u0) (err u1))
    (asserts! (>= target-amount MINIMUM-FUNDING-AMOUNT) (err u2))
    (map-set initiatives
      { initiative-id: initiative-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        category: category,
        target-amount: target-amount,
        current-amount: u0,
        deadline: deadline,
        status: "active",
        created-at: burn-block-height,
        beneficiaries: beneficiaries
      }
    )
    (var-set next-initiative-id (+ initiative-id u1))
    (ok initiative-id)
  )
)

;; Contribute STX to an initiative
(define-public (contribute (initiative-id uint) (amount uint))
  (let
    (
      (initiative (unwrap! (map-get? initiatives { initiative-id: initiative-id }) (err u3)))
      (current-amount (get current-amount initiative))
      (fee-amount (/ (* amount PLATFORM-FEE-PERCENTAGE) u100))
    )
    (asserts! (> amount u0) (err u4))
    (asserts! (is-eq (get status initiative) "active") (err u5))
    (asserts! (< burn-block-height (get deadline initiative)) (err u6))
    (asserts! (<= (+ current-amount amount) (get target-amount initiative)) (err u7))

    ;; Transfer STX from contributor to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    ;; Update initiative current amount
    (map-set initiatives
      { initiative-id: initiative-id }
      (merge initiative { current-amount: (+ current-amount amount) })
    )

    ;; Record contribution
    (map-set contributions
      { contributor: tx-sender, initiative-id: initiative-id }
      {
        amount: amount,
        contributed-at: burn-block-height,
        withdrawn: false
      }
    )

    ;; Update platform balance and total funded
    (var-set platform-balance (+ (var-get platform-balance) fee-amount))
    (var-set total-funded (+ (var-get total-funded) amount))

    (ok true)
  )
)

;; Release funds to initiative creator after deadline and target reached
(define-public (release-funds (initiative-id uint))
  (let
    (
      (initiative (unwrap! (map-get? initiatives { initiative-id: initiative-id }) (err u8)))
      (creator (get creator initiative))
      (amount (get current-amount initiative))
    )
    (asserts! (is-eq tx-sender creator) (err u9))
    (asserts! (>= burn-block-height (get deadline initiative)) (err u10))
    (asserts! (>= (get current-amount initiative) (get target-amount initiative)) (err u11))
    (asserts! (is-eq (get status initiative) "active") (err u12))

    ;; Update status to funded
    (map-set initiatives
      { initiative-id: initiative-id }
      (merge initiative { status: "funded" })
    )

    ;; Transfer funds to creator
    (try! (stx-transfer? amount (as-contract tx-sender) creator))

    (ok true)
  )
)

;; Withdraw contribution if target not met after deadline
(define-public (withdraw-contribution (initiative-id uint))
  (let
    (
      (initiative (unwrap! (map-get? initiatives { initiative-id: initiative-id }) (err u13)))
      (contribution (unwrap! (map-get? contributions { contributor: tx-sender, initiative-id: initiative-id }) (err u14)))
      (amount (get amount contribution))
    )
    (asserts! (>= burn-block-height (get deadline initiative)) (err u15))
    (asserts! (< (get current-amount initiative) (get target-amount initiative)) (err u16))
    (asserts! (is-eq (get withdrawn contribution) false) (err u17))

    ;; Mark as withdrawn
    (map-set contributions
      { contributor: tx-sender, initiative-id: initiative-id }
      (merge contribution { withdrawn: true })
    )

    ;; Transfer funds back to contributor
    (try! (stx-transfer? amount (as-contract tx-sender) tx-sender))

    (ok true)
  )
)

;; Get initiative details
(define-read-only (get-initiative (initiative-id uint))
  (match (map-get? initiatives { initiative-id: initiative-id })
    initiative (ok initiative)
    (err u18)
  )
)

;; Get contribution details
(define-read-only (get-contribution (contributor principal) (initiative-id uint))
  (match (map-get? contributions { contributor: contributor, initiative-id: initiative-id })
    contribution (ok contribution)
    (err u19)
  )
)

;; Get platform stats
(define-read-only (get-platform-stats)
  {
    platform-balance: (var-get platform-balance),
    total-funded: (var-get total-funded),
    total-initiatives: (var-get next-initiative-id)
  }
)

;; Check if initiative is active
(define-read-only (is-initiative-active (initiative-id uint))
  (match (map-get? initiatives { initiative-id: initiative-id })
    initiative
      (and
        (is-eq (get status initiative) "active")
        (< burn-block-height (get deadline initiative))
      )
    false
  )
)

;; Get current initiative count
(define-read-only (get-total-initiatives)
  (var-get next-initiative-id)
)

;; Get platform balance
(define-read-only (get-platform-balance)
  (var-get platform-balance)
)

;; Get total funded
(define-read-only (get-total-funded)
  (var-get total-funded)
)

;; Withdraw platform fees (only deployer)
(define-public (withdraw-platform-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender DEPLOYER) (err u20))
    (asserts! (<= amount (var-get platform-balance)) (err u21))
    (try! (stx-transfer? amount (as-contract tx-sender) tx-sender))
    (var-set platform-balance (- (var-get platform-balance) amount))
    (ok true)
  )
)