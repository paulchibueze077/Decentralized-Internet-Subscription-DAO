(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_FUNDS (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u103))
(define-constant ERR_ALREADY_VOTED (err u104))
(define-constant ERR_VOTING_ENDED (err u105))
(define-constant ERR_PROPOSAL_NOT_PASSED (err u106))
(define-constant ERR_ALREADY_MEMBER (err u107))
(define-constant ERR_NOT_MEMBER (err u108))
(define-constant ERR_INVALID_DURATION (err u109))

(define-data-var total-pool uint u0)
(define-data-var next-proposal-id uint u1)
(define-data-var membership-fee uint u1000000)
(define-data-var min-proposal-amount uint u500000)

(define-map members principal 
  {
    contribution: uint,
    joined-at: uint,
    active: bool
  }
)

(define-map proposals uint
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    amount: uint,
    recipient: principal,
    votes-for: uint,
    votes-against: uint,
    created-at: uint,
    voting-ends-at: uint,
    executed: bool,
    passed: bool
  }
)

(define-map votes {proposal-id: uint, voter: principal} bool)

(define-map internet-subscriptions uint
  {
    provider: (string-ascii 50),
    monthly-cost: uint,
    speed: (string-ascii 20),
    active: bool,
    funded-until: uint
  }
)

(define-data-var next-subscription-id uint u1)

(define-public (join-dao)
  (let ((membership-cost (var-get membership-fee)))
    (asserts! (is-none (map-get? members tx-sender)) ERR_ALREADY_MEMBER)
    (try! (stx-transfer? membership-cost tx-sender (as-contract tx-sender)))
    (map-set members tx-sender
      {
        contribution: membership-cost,
        joined-at: stacks-block-height,
        active: true
      }
    )
    (var-set total-pool (+ (var-get total-pool) membership-cost))
    (ok true)
  )
)

(define-public (contribute (amount uint))
  (let ((member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER)))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get active member-data) ERR_NOT_AUTHORIZED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set members tx-sender
      (merge member-data {contribution: (+ (get contribution member-data) amount)})
    )
    (var-set total-pool (+ (var-get total-pool) amount))
    (ok true)
  )
)

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) (amount uint) (recipient principal))
  (let ((proposal-id (var-get next-proposal-id))
        (member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER)))
    (asserts! (get active member-data) ERR_NOT_AUTHORIZED)
    (asserts! (>= amount (var-get min-proposal-amount)) ERR_INVALID_AMOUNT)
    (asserts! (<= amount (var-get total-pool)) ERR_INSUFFICIENT_FUNDS)
    (map-set proposals proposal-id
      {
        proposer: tx-sender,
        title: title,
        description: description,
        amount: amount,
        recipient: recipient,
        votes-for: u0,
        votes-against: u0,
        created-at: stacks-block-height,
        voting-ends-at: (+ stacks-block-height u144),
        executed: false,
        passed: false
      }
    )
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote (proposal-id uint) (support bool))
  (let ((proposal-data (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
        (member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
        (vote-key {proposal-id: proposal-id, voter: tx-sender}))
    (asserts! (get active member-data) ERR_NOT_AUTHORIZED)
    (asserts! (< stacks-block-height (get voting-ends-at proposal-data)) ERR_VOTING_ENDED)
    (asserts! (is-none (map-get? votes vote-key)) ERR_ALREADY_VOTED)
    (map-set votes vote-key true)
    (if support
      (map-set proposals proposal-id
        (merge proposal-data {votes-for: (+ (get votes-for proposal-data) u1)})
      )
      (map-set proposals proposal-id
        (merge proposal-data {votes-against: (+ (get votes-against proposal-data) u1)})
      )
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let ((proposal-data (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (>= stacks-block-height (get voting-ends-at proposal-data)) ERR_VOTING_ENDED)
    (asserts! (not (get executed proposal-data)) ERR_NOT_AUTHORIZED)
    (let ((total-votes (+ (get votes-for proposal-data) (get votes-against proposal-data)))
          (passed (> (get votes-for proposal-data) (get votes-against proposal-data))))
      (map-set proposals proposal-id
        (merge proposal-data {executed: true, passed: passed})
      )
      (if (and passed (>= (var-get total-pool) (get amount proposal-data)))
        (begin
          (try! (as-contract (stx-transfer? (get amount proposal-data) tx-sender (get recipient proposal-data))))
          (var-set total-pool (- (var-get total-pool) (get amount proposal-data)))
          (ok true)
        )
        (ok false)
      )
    )
  )
)

(define-public (add-internet-subscription (provider (string-ascii 50)) (monthly-cost uint) (speed (string-ascii 20)) (duration-months uint))
  (let ((subscription-id (var-get next-subscription-id))
        (total-cost (* monthly-cost duration-months)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> duration-months u0) ERR_INVALID_DURATION)
    (asserts! (<= total-cost (var-get total-pool)) ERR_INSUFFICIENT_FUNDS)
    (map-set internet-subscriptions subscription-id
      {
        provider: provider,
        monthly-cost: monthly-cost,
        speed: speed,
        active: true,
        funded-until: (+ stacks-block-height (* duration-months u4320))
      }
    )
    (var-set next-subscription-id (+ subscription-id u1))
    (var-set total-pool (- (var-get total-pool) total-cost))
    (ok subscription-id)
  )
)

(define-public (renew-subscription (subscription-id uint) (duration-months uint))
  (let ((subscription-data (unwrap! (map-get? internet-subscriptions subscription-id) ERR_PROPOSAL_NOT_FOUND))
        (renewal-cost (* (get monthly-cost subscription-data) duration-months)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> duration-months u0) ERR_INVALID_DURATION)
    (asserts! (<= renewal-cost (var-get total-pool)) ERR_INSUFFICIENT_FUNDS)
    (map-set internet-subscriptions subscription-id
      (merge subscription-data 
        {
          funded-until: (+ (get funded-until subscription-data) (* duration-months u4320)),
          active: true
        }
      )
    )
    (var-set total-pool (- (var-get total-pool) renewal-cost))
    (ok true)
  )
)

(define-public (deactivate-subscription (subscription-id uint))
  (let ((subscription-data (unwrap! (map-get? internet-subscriptions subscription-id) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set internet-subscriptions subscription-id
      (merge subscription-data {active: false})
    )
    (ok true)
  )
)

(define-public (update-membership-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> new-fee u0) ERR_INVALID_AMOUNT)
    (var-set membership-fee new-fee)
    (ok true)
  )
)

(define-read-only (get-member-info (member principal))
  (map-get? members member)
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-subscription (subscription-id uint))
  (map-get? internet-subscriptions subscription-id)
)

(define-read-only (get-total-pool)
  (var-get total-pool)
)

(define-read-only (get-membership-fee)
  (var-get membership-fee)
)

(define-read-only (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? votes {proposal-id: proposal-id, voter: voter}))
)

(define-read-only (is-subscription-active (subscription-id uint))
  (match (map-get? internet-subscriptions subscription-id)
    subscription (and (get active subscription) (> (get funded-until subscription) stacks-block-height))
    false
  )
)
