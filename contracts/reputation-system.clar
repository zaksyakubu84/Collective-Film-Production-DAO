(define-constant REPUTATION_VOTE_POINTS u10)
(define-constant REPUTATION_PROPOSAL_SUCCESS_POINTS u50)
(define-constant REPUTATION_PROPOSAL_FAILURE_PENALTY u5)

(define-map member-reputation
  principal
  {
    score: uint,
    votes-cast: uint,
    proposals-created: uint,
    successful-proposals: uint
  }
)

(define-private (update-reputation (member principal) (score-change int) (votes-change uint) (proposals-change uint) (success-change uint))
  (let ((current-rep (default-to {score: u0, votes-cast: u0, proposals-created: u0, successful-proposals: u0} 
                                (map-get? member-reputation member))))
    (map-set member-reputation member {
      score: (if (>= score-change 0) 
               (+ (get score current-rep) (to-uint score-change))
               (if (>= (get score current-rep) (to-uint (- score-change)))
                 (- (get score current-rep) (to-uint (- score-change)))
                 u0)),
      votes-cast: (+ (get votes-cast current-rep) votes-change),
      proposals-created: (+ (get proposals-created current-rep) proposals-change),
      successful-proposals: (+ (get successful-proposals current-rep) success-change)
    })
  )
)

(define-public (record-vote (voter principal))
  (begin
    (update-reputation voter (to-int REPUTATION_VOTE_POINTS) u1 u0 u0)
    (ok true)
  )
)

(define-public (record-proposal-creation (creator principal))
  (begin
    (update-reputation creator 0 u0 u1 u0)
    (ok true)
  )
)

(define-public (record-proposal-success (creator principal))
  (begin
    (update-reputation creator (to-int REPUTATION_PROPOSAL_SUCCESS_POINTS) u0 u0 u1)
    (ok true)
  )
)

(define-public (record-proposal-failure (creator principal))
  (begin
    (update-reputation creator (to-int (- REPUTATION_PROPOSAL_FAILURE_PENALTY)) u0 u0 u0)
    (ok true)
  )
)

(define-read-only (get-member-reputation (member principal))
  (default-to {score: u0, votes-cast: u0, proposals-created: u0, successful-proposals: u0} 
              (map-get? member-reputation member))
)

(define-read-only (get-reputation-score (member principal))
  (get score (get-member-reputation member))
)

(define-read-only (calculate-engagement-ratio (member principal))
  (let ((rep-data (get-member-reputation member)))
    (if (> (get proposals-created rep-data) u0)
      (/ (* (get successful-proposals rep-data) u100) (get proposals-created rep-data))
      u0)
  )
)

(define-read-only (get-reputation-tier (member principal))
  (let ((score (get-reputation-score member)))
    (if (>= score u1000) "elite"
      (if (>= score u500) "experienced"
        (if (>= score u100) "active"
          (if (>= score u10) "member"
            "newcomer"))))
)
)