import { useEffect, useState } from 'react'
import { useStore } from '../store'
import { getScores, insertScore } from '../data'
import { readableTime, Scores } from './LeaderBoard'
import type { SavedScore } from '../data'

export const Finished = (): JSX.Element => {
  const [reset, time, displayName] = useStore(({ actions: { reset }, finished, displayName }) => [
    reset,
    finished,
    displayName,
  ])
  const [scoreId, setScoreId] = useState<SavedScore['id']>('')
  const [scores, setScores] = useState<SavedScore[]>([])
  const [position, setPosition] = useState<number>(0)

  const updateScores = () => {
    getScores().then(setScores)
  }

  const sendScore = () => {
    insertScore({ name: displayName ?? 'Player', time })
      .then(([{ id }]) => setScoreId(id))
      .then(updateScores)
      .then(() => {
        const index = scores.findIndex((s) => s.id === scoreId)
        setPosition(index + 1)
      })
  }

  const hasSaved = scoreId !== ''

  useEffect(updateScores, [time])

  return (
    <div className="finished">
      <div className="finished-header">
        <h1>Race Complete</h1>
        <p
          style={{
            fontFamily: "'Outfit', sans-serif",
            fontSize: '0.9em',
            color: 'rgba(255,245,245,0.6)',
            margin: '8px 0 0',
          }}
        >
          Your time: {readableTime(time)}s
        </p>
      </div>
      <div className="finished-leaderboard">
        <Scores className="leaderboard" scores={scores} />
      </div>
      <div className="finished-auth">
        {displayName ? (
          hasSaved ? (
            position > 0 ? (
              <p
                style={{
                  fontFamily: "'Cormorant Garamond', serif",
                  fontSize: '1.3em',
                  color: '#E8D5B7',
                  margin: 0,
                }}
              >
                Score saved! You are #{position}
              </p>
            ) : null
          ) : (
            <div className="auth-container">
              <p className="auth-header">Save your best time, {displayName}?</p>
              <button onClick={sendScore} className="auth-provider" style={{ width: 'auto', minWidth: 200 }}>
                Save Score
              </button>
            </div>
          )
        ) : (
          <p className="auth-header">Race and save your best times</p>
        )}
      </div>
      <div className="finished-restart">
        <button className="restart-btn" onClick={reset}>
          RACE AGAIN
        </button>
      </div>
    </div>
  )
}
