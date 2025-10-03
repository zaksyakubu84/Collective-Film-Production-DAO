(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_ESCROW_NOT_FOUND (err u301))
(define-constant ERR_ALREADY_CLAIMED (err u302))
(define-constant ERR_PROPOSAL_PENDING (err u303))
(define-constant ERR_INSUFFICIENT_BALANCE (err u304))
(define-constant ERR_INVALID_AMOUNT (err u305))

(define-constant ESCROW_PERCENTAGE u10)
(define-constant SUCCESS_BONUS u5)

(define-data-var total-escrow-pool uint u0)

(define-map proposal-escrows
  uint
  {
    creator: principal,
    locked-amount: uint,
    status: (string-ascii 10),
    voter-count: uint,
    claimed-voters: uint
  }
)

(define-map voter-claims
  {proposal-id: uint, voter: principal}
  bool
)

(define-public (lock-escrow (proposal-id uint) (proposal-amount uint))
  (let ((escrow-amount (/ (* proposal-amount ESCROW_PERCENTAGE) u100)))
    (asserts! (> escrow-amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? escrow-amount tx-sender (as-contract tx-sender)))
    (map-set proposal-escrows proposal-id {
      creator: tx-sender,
      locked-amount: escrow-amount,
      status: "pending",
      voter-count: u0,
      claimed-voters: u0
    })
    (var-set total-escrow-pool (+ (var-get total-escrow-pool) escrow-amount))
    (ok escrow-amount)
  )
)

(define-public (finalize-escrow-success (proposal-id uint))
  (let ((escrow (unwrap! (map-get? proposal-escrows proposal-id) ERR_ESCROW_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator escrow)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status escrow) "pending") ERR_ALREADY_CLAIMED)
    (let ((bonus (/ (* (get locked-amount escrow) SUCCESS_BONUS) u100))
          (total-return (+ (get locked-amount escrow) bonus)))
      (map-set proposal-escrows proposal-id (merge escrow {status: "success"}))
      (var-set total-escrow-pool (- (var-get total-escrow-pool) (get locked-amount escrow)))
      (as-contract (stx-transfer? total-return tx-sender (get creator escrow)))
    )
  )
)

(define-public (finalize-escrow-failure (proposal-id uint) (voter-count uint))
  (let ((escrow (unwrap! (map-get? proposal-escrows proposal-id) ERR_ESCROW_NOT_FOUND)))
    (asserts! (is-eq (get status escrow) "pending") ERR_ALREADY_CLAIMED)
    (map-set proposal-escrows proposal-id (merge escrow {
      status: "failed",
      voter-count: voter-count
    }))
    (ok true)
  )
)

(define-public (claim-voter-reward (proposal-id uint))
  (let ((escrow (unwrap! (map-get? proposal-escrows proposal-id) ERR_ESCROW_NOT_FOUND))
        (claim-key {proposal-id: proposal-id, voter: tx-sender}))
    (asserts! (is-eq (get status escrow) "failed") ERR_PROPOSAL_PENDING)
    (asserts! (is-none (map-get? voter-claims claim-key)) ERR_ALREADY_CLAIMED)
    (asserts! (> (get voter-count escrow) u0) ERR_INVALID_AMOUNT)
    (let ((reward (/ (get locked-amount escrow) (get voter-count escrow))))
      (map-set voter-claims claim-key true)
      (map-set proposal-escrows proposal-id 
        (merge escrow {claimed-voters: (+ (get claimed-voters escrow) u1)}))
      (as-contract (stx-transfer? reward tx-sender tx-sender))
    )
  )
)

(define-read-only (get-escrow-info (proposal-id uint))
  (map-get? proposal-escrows proposal-id)
)

(define-read-only (has-claimed-reward (proposal-id uint) (voter principal))
  (default-to false (map-get? voter-claims {proposal-id: proposal-id, voter: voter}))
)

(define-read-only (calculate-escrow-amount (proposal-amount uint))
  (/ (* proposal-amount ESCROW_PERCENTAGE) u100)
)

(define-read-only (get-total-escrow-pool)
  (var-get total-escrow-pool)
)