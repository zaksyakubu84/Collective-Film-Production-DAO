(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_PROPOSAL (err u101))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u102))
(define-constant ERR_ALREADY_VOTED (err u103))
(define-constant ERR_VOTING_CLOSED (err u104))
(define-constant ERR_INSUFFICIENT_FUNDS (err u105))
(define-constant ERR_INVALID_AMOUNT (err u106))
(define-constant ERR_PROPOSAL_ACTIVE (err u107))
(define-constant VOTING_PERIOD u144)
(define-constant MIN_PROPOSAL_THRESHOLD u1000)

(define-data-var proposal-counter uint u0)
(define-data-var total-treasury uint u0)

(define-fungible-token film-token)

(define-map proposals
  uint
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    amount: uint,
    recipient: principal,
    votes-for: uint,
    votes-against: uint,
    created-at: uint,
    executed: bool,
    creator: principal
  }
)

(define-map votes
  {proposal-id: uint, voter: principal}
  {vote: bool, amount: uint}
)

(define-map members
  principal
  {tokens: uint, joined-at: uint}
)

(define-public (contribute (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set total-treasury (+ (var-get total-treasury) amount))
    (match (map-get? members tx-sender)
      member (map-set members tx-sender {
        tokens: (+ (get tokens member) amount),
        joined-at: (get joined-at member)
      })
      (map-set members tx-sender {
        tokens: amount,
        joined-at: stacks-block-height
      })
    )
    (try! (ft-mint? film-token amount tx-sender))
    (ok amount)
  )
)

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) (amount uint) (recipient principal))
  (let ((proposal-id (+ (var-get proposal-counter) u1))
        (user-tokens (get-user-tokens tx-sender)))
    (asserts! (>= user-tokens MIN_PROPOSAL_THRESHOLD) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount (var-get total-treasury)) ERR_INSUFFICIENT_FUNDS)
    (map-set proposals proposal-id {
      title: title,
      description: description,
      amount: amount,
      recipient: recipient,
      votes-for: u0,
      votes-against: u0,
      created-at: stacks-block-height,
      executed: false,
      creator: tx-sender
    })
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

(define-public (vote (proposal-id uint) (support bool))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
        (user-tokens (get-user-tokens tx-sender))
        (vote-key {proposal-id: proposal-id, voter: tx-sender}))
    (asserts! (> user-tokens u0) ERR_UNAUTHORIZED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ACTIVE)
    (asserts! (is-none (map-get? votes vote-key)) ERR_ALREADY_VOTED)
    (asserts! (<= (- stacks-block-height (get created-at proposal)) VOTING_PERIOD) ERR_VOTING_CLOSED)
    (map-set votes vote-key {vote: support, amount: user-tokens})
    (if support
      (map-set proposals proposal-id (merge proposal {votes-for: (+ (get votes-for proposal) user-tokens)}))
      (map-set proposals proposal-id (merge proposal {votes-against: (+ (get votes-against proposal) user-tokens)}))
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ACTIVE)
    (asserts! (> (- stacks-block-height (get created-at proposal)) VOTING_PERIOD) ERR_VOTING_CLOSED)
    (asserts! (> (get votes-for proposal) (get votes-against proposal)) ERR_UNAUTHORIZED)
    (try! (as-contract (stx-transfer? (get amount proposal) tx-sender (get recipient proposal))))
    (var-set total-treasury (- (var-get total-treasury) (get amount proposal)))
    (map-set proposals proposal-id (merge proposal {executed: true}))
    (ok true)
  )
)

(define-public (delegate-tokens (recipient principal) (amount uint))
  (let ((user-tokens (get-user-tokens tx-sender)))
    (asserts! (>= user-tokens amount) ERR_INSUFFICIENT_FUNDS)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (ft-transfer? film-token amount tx-sender recipient))
    (ok true)
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-user-tokens (user principal))
  (default-to u0 (get tokens (map-get? members user)))
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-treasury-balance)
  (var-get total-treasury)
)

(define-read-only (get-proposal-count)
  (var-get proposal-counter)
)

(define-read-only (get-member-info (member principal))
  (map-get? members member)
)

(define-read-only (is-voting-open (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (and 
      (not (get executed proposal))
      (<= (- stacks-block-height (get created-at proposal)) VOTING_PERIOD)
    )
    false
  )
)

(define-read-only (get-proposal-status (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal {
      proposal-id: proposal-id,
      title: (get title proposal),
      votes-for: (get votes-for proposal),
      votes-against: (get votes-against proposal),
      executed: (get executed proposal),
      voting-open: (is-voting-open proposal-id),
      blocks-remaining: (if (<= (- stacks-block-height (get created-at proposal)) VOTING_PERIOD)
                          (- VOTING_PERIOD (- stacks-block-height (get created-at proposal)))
                          u0)
    }
    {
      proposal-id: u0,
      title: "",
      votes-for: u0,
      votes-against: u0,
      executed: false,
      voting-open: false,
      blocks-remaining: u0
    }
  )
)

(define-read-only (get-token-balance (owner principal))
  (ft-get-balance film-token owner)
)
