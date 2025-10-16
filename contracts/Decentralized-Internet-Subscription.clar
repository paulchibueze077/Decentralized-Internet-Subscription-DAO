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

(define-constant ERR_NO_REWARDS_AVAILABLE (err u110))
(define-constant ERR_REWARDS_ALREADY_CLAIMED (err u111))

(define-constant BRONZE_THRESHOLD u5000000)
(define-constant SILVER_THRESHOLD u10000000)
(define-constant GOLD_THRESHOLD u25000000)
(define-constant PLATINUM_THRESHOLD u50000000)

(define-constant ERR_EMERGENCY_NOT_FOUND (err u112))
(define-constant ERR_INSUFFICIENT_EMERGENCY_FUNDS (err u113))
(define-constant ERR_ALREADY_SIGNED (err u114))
(define-constant ERR_NOT_ENOUGH_SIGNATURES (err u115))
(define-constant REQUIRED_SIGNATURES u3)

(define-constant MINIMUM_STAKE_PERIOD u4320)
(define-constant MAXIMUM_STAKE_PERIOD u25920)
(define-constant BASE_MULTIPLIER u100)
(define-constant STAKE_BONUS_RATE u5)

(define-constant ERR_INSUFFICIENT_CREDITS (err u116))
(define-constant ERR_SUBSCRIPTION_NOT_ACTIVE (err u117))
(define-constant ERR_ALREADY_REGISTERED (err u118))
(define-constant ERR_NOT_REGISTERED (err u119))
(define-constant CREDIT_MULTIPLIER u10)

(define-data-var emergency-fund uint u0)
(define-data-var next-emergency-id uint u1)

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

(define-map member-rewards principal
  {
    reputation-points: uint,
    milestone-level: uint,
    rewards-claimed: uint
  }
)

(define-private (calculate-reward-points (total-contribution uint))
  (if (>= total-contribution PLATINUM_THRESHOLD)
    u500
    (if (>= total-contribution GOLD_THRESHOLD)
      u250
      (if (>= total-contribution SILVER_THRESHOLD)
        u100
        (if (>= total-contribution BRONZE_THRESHOLD)
          u50
          u0
        )
      )
    )
  )
)

(define-private (get-milestone-level (total-contribution uint))
  (if (>= total-contribution PLATINUM_THRESHOLD)
    u4
    (if (>= total-contribution GOLD_THRESHOLD)
      u3
      (if (>= total-contribution SILVER_THRESHOLD)
        u2
        (if (>= total-contribution BRONZE_THRESHOLD)
          u1
          u0
        )
      )
    )
  )
)

(define-public (claim-rewards)
  (let ((member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
        (current-rewards (default-to {reputation-points: u0, milestone-level: u0, rewards-claimed: u0}
                          (map-get? member-rewards tx-sender)))
        (total-contribution (get contribution member-data))
        (new-reputation-points (calculate-reward-points total-contribution))
        (new-milestone-level (get-milestone-level total-contribution)))
    (asserts! (get active member-data) ERR_NOT_AUTHORIZED)
    (asserts! (> new-reputation-points (get reputation-points current-rewards)) ERR_NO_REWARDS_AVAILABLE)
    (map-set member-rewards tx-sender
      {
        reputation-points: new-reputation-points,
        milestone-level: new-milestone-level,
        rewards-claimed: (+ (get rewards-claimed current-rewards) 
                           (- new-reputation-points (get reputation-points current-rewards)))
      }
    )
    (ok new-reputation-points)
  )
)

(define-read-only (get-member-rewards (member principal))
  (map-get? member-rewards member)
)

(define-read-only (get-available-rewards (member principal))
  (match (map-get? members member)
    member-data
    (let ((total-contribution (get contribution member-data))
          (current-rewards (default-to {reputation-points: u0, milestone-level: u0, rewards-claimed: u0}
                            (map-get? member-rewards member)))
          (available-points (calculate-reward-points total-contribution)))
      (some (- available-points (get reputation-points current-rewards))))
    none
  )
)


(define-map emergency-proposals uint
  {
    title: (string-ascii 80),
    amount: uint,
    recipient: principal,
    signatures: uint,
    executed: bool,
    created-at: uint
  }
)

(define-map emergency-signatures {proposal-id: uint, signer: principal} bool)

(define-public (contribute-emergency (amount uint))
  (let ((member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER)))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get active member-data) ERR_NOT_AUTHORIZED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set emergency-fund (+ (var-get emergency-fund) amount))
    (ok true)
  )
)

(define-public (create-emergency-proposal (title (string-ascii 80)) (amount uint) (recipient principal))
  (let ((proposal-id (var-get next-emergency-id))
        (member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER)))
    (asserts! (get active member-data) ERR_NOT_AUTHORIZED)
    (asserts! (>= (get contribution member-data) GOLD_THRESHOLD) ERR_NOT_AUTHORIZED)
    (asserts! (<= amount (var-get emergency-fund)) ERR_INSUFFICIENT_EMERGENCY_FUNDS)
    (map-set emergency-proposals proposal-id
      {
        title: title,
        amount: amount,
        recipient: recipient,
        signatures: u1,
        executed: false,
        created-at: stacks-block-height
      }
    )
    (map-set emergency-signatures {proposal-id: proposal-id, signer: tx-sender} true)
    (var-set next-emergency-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (sign-emergency (proposal-id uint))
  (let ((proposal-data (unwrap! (map-get? emergency-proposals proposal-id) ERR_EMERGENCY_NOT_FOUND))
        (member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
        (signature-key {proposal-id: proposal-id, signer: tx-sender}))
    (asserts! (get active member-data) ERR_NOT_AUTHORIZED)
    (asserts! (>= (get contribution member-data) SILVER_THRESHOLD) ERR_NOT_AUTHORIZED)
    (asserts! (not (get executed proposal-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-none (map-get? emergency-signatures signature-key)) ERR_ALREADY_SIGNED)
    (map-set emergency-signatures signature-key true)
    (map-set emergency-proposals proposal-id
      (merge proposal-data {signatures: (+ (get signatures proposal-data) u1)})
    )
    (ok true)
  )
)

(define-public (execute-emergency (proposal-id uint))
  (let ((proposal-data (unwrap! (map-get? emergency-proposals proposal-id) ERR_EMERGENCY_NOT_FOUND)))
    (asserts! (not (get executed proposal-data)) ERR_NOT_AUTHORIZED)
    (asserts! (>= (get signatures proposal-data) REQUIRED_SIGNATURES) ERR_NOT_ENOUGH_SIGNATURES)
    (try! (as-contract (stx-transfer? (get amount proposal-data) tx-sender (get recipient proposal-data))))
    (var-set emergency-fund (- (var-get emergency-fund) (get amount proposal-data)))
    (map-set emergency-proposals proposal-id (merge proposal-data {executed: true}))
    (ok true)
  )
)

(define-read-only (get-emergency-fund)
  (var-get emergency-fund)
)

(define-read-only (get-emergency-proposal (proposal-id uint))
  (map-get? emergency-proposals proposal-id)
)


(define-map member-stakes principal
  {
    staked-amount: uint,
    stake-start: uint,
    stake-end: uint,
    accumulated-rewards: uint,
    last-claim: uint
  }
)

(define-data-var total-staked uint u0)

(define-public (stake-tokens (amount uint) (lock-period uint))
  (let ((member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
        (current-stake (default-to 
          {staked-amount: u0, stake-start: u0, stake-end: u0, accumulated-rewards: u0, last-claim: u0}
          (map-get? member-stakes tx-sender))))
    (asserts! (get active member-data) ERR_NOT_AUTHORIZED)
    (asserts! (>= amount u100000) ERR_INVALID_AMOUNT)
    (asserts! (>= lock-period MINIMUM_STAKE_PERIOD) ERR_INVALID_DURATION)
    (asserts! (<= lock-period MAXIMUM_STAKE_PERIOD) ERR_INVALID_DURATION)
    (asserts! (is-eq (get staked-amount current-stake) u0) ERR_ALREADY_MEMBER)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set member-stakes tx-sender
      {
        staked-amount: amount,
        stake-start: stacks-block-height,
        stake-end: (+ stacks-block-height lock-period),
        accumulated-rewards: u0,
        last-claim: stacks-block-height
      }
    )
    (var-set total-staked (+ (var-get total-staked) amount))
    (ok true)
  )
)

(define-public (unstake-tokens)
  (let ((stake-data (unwrap! (map-get? member-stakes tx-sender) ERR_NOT_MEMBER)))
    (asserts! (>= stacks-block-height (get stake-end stake-data)) ERR_VOTING_ENDED)
    (asserts! (> (get staked-amount stake-data) u0) ERR_INVALID_AMOUNT)
    (let ((total-return (+ (get staked-amount stake-data) (get accumulated-rewards stake-data))))
      (try! (as-contract (stx-transfer? total-return tx-sender tx-sender)))
      (var-set total-staked (- (var-get total-staked) (get staked-amount stake-data)))
      (map-delete member-stakes tx-sender)
      (ok total-return)
    )
  )
)

(define-public (claim-staking-rewards)
  (let ((stake-data (unwrap! (map-get? member-stakes tx-sender) ERR_NOT_MEMBER))
        (time-elapsed (- stacks-block-height (get last-claim stake-data))))
    (asserts! (> time-elapsed u144) ERR_NO_REWARDS_AVAILABLE)
    (let ((reward-rate (/ (* (get staked-amount stake-data) STAKE_BONUS_RATE) u10000))
          (new-rewards (* reward-rate (/ time-elapsed u144))))
      (map-set member-stakes tx-sender
        (merge stake-data 
          {
            accumulated-rewards: (+ (get accumulated-rewards stake-data) new-rewards),
            last-claim: stacks-block-height
          }
        )
      )
      (ok new-rewards)
    )
  )
)

(define-private (get-voting-multiplier (voter principal))
  (match (map-get? member-stakes voter)
    stake-data 
    (let ((remaining-time (if (> (get stake-end stake-data) stacks-block-height)
                            (- (get stake-end stake-data) stacks-block-height)
                            u0)))
      (+ BASE_MULTIPLIER (/ (* remaining-time u50) u4320))
    )
    BASE_MULTIPLIER
  )
)

(define-read-only (get-stake-info (member principal))
  (map-get? member-stakes member)
)

(define-map subscription-members {subscription-id: uint, member: principal}
  {
    enrolled-at: uint,
    share-percentage: uint,
    active: bool
  }
)

(define-map member-usage-credits principal
  {
    available-credits: uint,
    total-earned: uint,
    total-spent: uint
  }
)

(define-data-var total-subscription-members uint u0)

(define-private (calculate-member-credits (contribution-amount uint))
  (/ (* contribution-amount CREDIT_MULTIPLIER) u1000000)
)

(define-public (register-for-subscription (subscription-id uint))
  (let ((subscription-data (unwrap! (map-get? internet-subscriptions subscription-id) ERR_PROPOSAL_NOT_FOUND))
        (member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
        (enrollment-key {subscription-id: subscription-id, member: tx-sender})
        (current-credits (default-to {available-credits: u0, total-earned: u0, total-spent: u0}
                         (map-get? member-usage-credits tx-sender)))
        (required-credits (calculate-member-credits (get monthly-cost subscription-data)))
        (new-earned-credits (calculate-member-credits (get contribution member-data))))
    (asserts! (get active member-data) ERR_NOT_AUTHORIZED)
    (asserts! (get active subscription-data) ERR_SUBSCRIPTION_NOT_ACTIVE)
    (asserts! (is-none (map-get? subscription-members enrollment-key)) ERR_ALREADY_REGISTERED)
    (let ((updated-credits (+ (get available-credits current-credits) new-earned-credits)))
      (asserts! (>= updated-credits required-credits) ERR_INSUFFICIENT_CREDITS)
      (map-set subscription-members enrollment-key
        {
          enrolled-at: stacks-block-height,
          share-percentage: u100,
          active: true
        }
      )
      (map-set member-usage-credits tx-sender
        {
          available-credits: (- updated-credits required-credits),
          total-earned: (+ (get total-earned current-credits) new-earned-credits),
          total-spent: (+ (get total-spent current-credits) required-credits)
        }
      )
      (var-set total-subscription-members (+ (var-get total-subscription-members) u1))
      (ok true)
    )
  )
)

(define-public (unregister-from-subscription (subscription-id uint))
  (let ((enrollment-key {subscription-id: subscription-id, member: tx-sender})
        (enrollment-data (unwrap! (map-get? subscription-members enrollment-key) ERR_NOT_REGISTERED)))
    (asserts! (get active enrollment-data) ERR_NOT_AUTHORIZED)
    (map-set subscription-members enrollment-key (merge enrollment-data {active: false}))
    (var-set total-subscription-members (- (var-get total-subscription-members) u1))
    (ok true)
  )
)

(define-read-only (get-subscription-enrollment (subscription-id uint) (member principal))
  (map-get? subscription-members {subscription-id: subscription-id, member: member})
)

(define-read-only (get-usage-credits (member principal))
  (map-get? member-usage-credits member)
)

(define-read-only (calculate-required-credits (subscription-id uint))
  (match (map-get? internet-subscriptions subscription-id)
    subscription-data (some (calculate-member-credits (get monthly-cost subscription-data)))
    none
  )
)