import { Crown, LockKeyhole } from 'lucide-react'

export default function PremiumGate({ premium, onUpgrade, children, copy }: { premium: boolean, onUpgrade: () => void, children: React.ReactNode, copy: { feature: string, sub: string, upgrade: string, eyebrow: string, foot: string } }) {
  if (premium) return <>{children}</>
  return <section className="premium-gate">
    <span className="premium-lock"><LockKeyhole /></span>
    <span className="eyebrow"><Crown size={14}/> {copy.eyebrow}</span>
    <h1>{copy.feature}</h1>
    <p>{copy.sub}</p>
    <button className="primary" onClick={onUpgrade}>{copy.upgrade}</button>
    <small>{copy.foot}</small>
  </section>
}
