(define-constant ERR_NOT_FOUND (err u200))
(define-constant ERR_UNAUTHORIZED (err u201))
(define-constant ERR_ALREADY_COMPLETED (err u202))
(define-constant ERR_INSUFFICIENT_VOTES (err u203))
(define-constant ERR_INVALID_MILESTONE (err u204))
(define-constant MIN_VERIFICATION_VOTES u3)

(define-data-var project-counter uint u0)

(define-map projects
  uint
  {
    creator: principal,
    title: (string-ascii 80),
    total-budget: uint,
    released-funds: uint,
    active: bool
  }
)

(define-map milestones
  {project-id: uint, milestone-id: uint}
  {
    description: (string-ascii 120),
    budget-percentage: uint,
    completed: bool,
    verification-votes: uint,
    evidence-hash: (string-ascii 64)
  }
)

(define-map milestone-votes
  {project-id: uint, milestone-id: uint, voter: principal}
  bool
)

(define-public (create-project (title (string-ascii 80)) (budget uint))
  (let ((project-id (+ (var-get project-counter) u1)))
    (map-set projects project-id {
      creator: tx-sender,
      title: title,
      total-budget: budget,
      released-funds: u0,
      active: true
    })
    (var-set project-counter project-id)
    (ok project-id)
  )
)

(define-public (add-milestone (project-id uint) (milestone-id uint) (description (string-ascii 120)) (budget-percentage uint))
  (let ((project (unwrap! (map-get? projects project-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator project)) ERR_UNAUTHORIZED)
    (asserts! (<= budget-percentage u100) ERR_INVALID_MILESTONE)
    (map-set milestones {project-id: project-id, milestone-id: milestone-id} {
      description: description,
      budget-percentage: budget-percentage,
      completed: false,
      verification-votes: u0,
      evidence-hash: ""
    })
    (ok true)
  )
)

(define-public (submit-milestone-evidence (project-id uint) (milestone-id uint) (evidence-hash (string-ascii 64)))
  (let ((project (unwrap! (map-get? projects project-id) ERR_NOT_FOUND))
        (milestone-key {project-id: project-id, milestone-id: milestone-id})
        (milestone (unwrap! (map-get? milestones milestone-key) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator project)) ERR_UNAUTHORIZED)
    (asserts! (not (get completed milestone)) ERR_ALREADY_COMPLETED)
    (map-set milestones milestone-key (merge milestone {evidence-hash: evidence-hash}))
    (ok true)
  )
)

(define-public (verify-milestone (project-id uint) (milestone-id uint))
  (let ((milestone-key {project-id: project-id, milestone-id: milestone-id})
        (milestone (unwrap! (map-get? milestones milestone-key) ERR_NOT_FOUND))
        (vote-key {project-id: project-id, milestone-id: milestone-id, voter: tx-sender}))
    (asserts! (is-none (map-get? milestone-votes vote-key)) ERR_UNAUTHORIZED)
    (asserts! (not (get completed milestone)) ERR_ALREADY_COMPLETED)
    (map-set milestone-votes vote-key true)
    (let ((new-votes (+ (get verification-votes milestone) u1)))
      (map-set milestones milestone-key (merge milestone {verification-votes: new-votes}))
      (if (>= new-votes MIN_VERIFICATION_VOTES)
        (begin
          (map-set milestones milestone-key (merge milestone {completed: true}))
          (unwrap! (release-milestone-funds project-id milestone-id) (err u999))
          (ok true)
        )
        (ok true)
      )
    )
  )
)

(define-private (release-milestone-funds (project-id uint) (milestone-id uint))
  (let ((project (unwrap! (map-get? projects project-id) ERR_NOT_FOUND))
        (milestone (unwrap! (map-get? milestones {project-id: project-id, milestone-id: milestone-id}) ERR_NOT_FOUND)))
    (let ((release-amount (/ (* (get total-budget project) (get budget-percentage milestone)) u100)))
      (map-set projects project-id 
        (merge project {released-funds: (+ (get released-funds project) release-amount)}))
      (ok release-amount)
    )
  )
)

(define-read-only (get-project (project-id uint))
  (map-get? projects project-id)
)

(define-read-only (get-milestone (project-id uint) (milestone-id uint))
  (map-get? milestones {project-id: project-id, milestone-id: milestone-id})
)

(define-read-only (get-project-progress (project-id uint))
  (match (map-get? projects project-id)
    project (/ (* (get released-funds project) u100) (get total-budget project))
    u0
  )
)
