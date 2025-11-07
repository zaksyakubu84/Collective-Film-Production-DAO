(define-constant ERR_PROPOSAL_NOT_FOUND (err u400))
(define-constant ERR_VOTING_CLOSED (err u401))
(define-constant ERR_ALREADY_EXTENDED (err u402))
(define-constant ERR_INSUFFICIENT_VOTES (err u403))
(define-constant ERR_ALREADY_VOTED (err u404))
(define-constant ERR_INVALID_AMOUNT (err u405))

(define-constant EXTENSION_BLOCKS u72)
(define-constant MIN_EXTENSION_VOTES u5)
(define-constant EXTENSION_COST u100000)

(define-data-var total-extensions uint u0)

(define-map extension-requests
  uint
  {
    requester: principal,
    support-votes: uint,
    against-votes: uint,
    extended: bool,
    requested-at: uint
  }
)

(define-map extension-voters
  {proposal-id: uint, voter: principal}
  bool
)

(define-map proposal-extensions
  uint
  {
    extension-count: uint,
    total-blocks-added: uint
  }
)

(define-public (request-extension (proposal-id uint))
  (let ((extension-fee EXTENSION_COST))
    (asserts! (> proposal-id u0) ERR_PROPOSAL_NOT_FOUND)
    (asserts! (is-none (map-get? extension-requests proposal-id)) ERR_ALREADY_EXTENDED)
    (map-set extension-requests proposal-id {
      requester: tx-sender,
      support-votes: u0,
      against-votes: u0,
      extended: false,
      requested-at: stacks-block-height
    })
    (ok proposal-id)
  )
)

(define-public (vote-on-extension (proposal-id uint) (support bool))
  (let ((request (unwrap! (map-get? extension-requests proposal-id) ERR_PROPOSAL_NOT_FOUND))
        (vote-key {proposal-id: proposal-id, voter: tx-sender}))
    (asserts! (not (get extended request)) ERR_ALREADY_EXTENDED)
    (asserts! (is-none (map-get? extension-voters vote-key)) ERR_ALREADY_VOTED)
    (map-set extension-voters vote-key true)
    (if support
      (map-set extension-requests proposal-id (merge request {support-votes: (+ (get support-votes request) u1)}))
      (map-set extension-requests proposal-id (merge request {against-votes: (+ (get against-votes request) u1)}))
    )
    (try! (check-and-execute-extension proposal-id))
    (ok true)
  )
)

(define-private (check-and-execute-extension (proposal-id uint))
  (let ((request (unwrap! (map-get? extension-requests proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (if (>= (get support-votes request) MIN_EXTENSION_VOTES)
      (begin
        (map-set extension-requests proposal-id (merge request {extended: true}))
        (let ((current-extension (default-to {extension-count: u0, total-blocks-added: u0} 
                                            (map-get? proposal-extensions proposal-id))))
          (map-set proposal-extensions proposal-id {
            extension-count: (+ (get extension-count current-extension) u1),
            total-blocks-added: (+ (get total-blocks-added current-extension) EXTENSION_BLOCKS)
          })
          (var-set total-extensions (+ (var-get total-extensions) u1))
          (ok true)
        )
      )
      (ok false)
    )
  )
)

(define-read-only (get-extension-request (proposal-id uint))
  (map-get? extension-requests proposal-id)
)

(define-read-only (get-proposal-extension-info (proposal-id uint))
  (default-to {extension-count: u0, total-blocks-added: u0} 
              (map-get? proposal-extensions proposal-id))
)

(define-read-only (has-voted-on-extension (proposal-id uint) (voter principal))
  (default-to false (map-get? extension-voters {proposal-id: proposal-id, voter: voter}))
)

(define-read-only (get-total-extensions)
  (var-get total-extensions)
)
