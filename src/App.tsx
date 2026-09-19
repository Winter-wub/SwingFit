import React, { useState, useEffect } from 'react';
import { 
  Activity, 
  Watch, 
  Flame, 
  Heart, 
  RotateCcw, 
  Trophy, 
  Zap, 
  ShieldAlert, 
  Sliders, 
  CheckCircle2, 
  Sparkles,
  ChevronRight,
  Code2,
  RefreshCw,
  Play,
  Pause,
  Send,
  Loader2,
  Bot
} from 'lucide-react';

type Sport = 'Badminton' | 'Pickleball';

type BadmintonStroke = 'Smash' | 'Clear' | 'Drop Shot' | 'Drive' | 'Net Shot' | 'Lift' | 'Serve';
type PickleballStroke = 'Dink' | 'Forehand' | 'Backhand' | 'Overhead Smash' | 'Serve';
type SwingStroke = BadmintonStroke | PickleballStroke;

interface SwingEvent {
  id: string;
  type: SwingStroke;
  sport: Sport;
  timestamp: string;
  peakAcceleration: number; // in G's
  speedMph: number;
}

interface MatchRecord {
  id: string;
  sport: Sport;
  date: string;
  durationMinutes: number;
  finalScore: string;
  won: boolean;
  totalSwings: number;
  avgHeartRate: number;
  activeCalories: number;
  highlightStat: string;
  coachInsight: string;
}

export default function App() {
  // Current Selected Sport
  const [sport, setSport] = useState<Sport>('Badminton');

  // Badminton BWF 21-point Score Engine State
  const [badmintonMyScore, setBadmintonMyScore] = useState(18);
  const [badmintonOppScore, setBadmintonOppScore] = useState(16);
  const [badmintonServer, setBadmintonServer] = useState<'US' | 'THEM'>('US');
  const [badmintonHistory, setBadmintonHistory] = useState<Array<{ my: number; opp: number; server: 'US' | 'THEM' }>>([]);

  // Pickleball 0-0-2 Engine State
  const [pbMyScore, setPbMyScore] = useState(7);
  const [pbOppScore, setPbOppScore] = useState(5);
  const [pbServingTeam, setPbServingTeam] = useState<'US' | 'THEM'>('US');
  const [pbServerNumber, setPbServerNumber] = useState<1 | 2>(1);
  const [pbHistory, setPbHistory] = useState<Array<{ my: number; opp: number; team: 'US' | 'THEM'; server: 1 | 2 }>>([]);

  // Session State
  const [isMatchActive, setIsMatchActive] = useState(true);
  const [matchSeconds, setMatchSeconds] = useState(1340);
  const [heartRate, setHeartRate] = useState(162);
  const [calories, setCalories] = useState(345);
  const [hittingHand, setHittingHand] = useState<'right' | 'left'>('right');
  const [sensitivity, setSensitivity] = useState<'low' | 'medium' | 'high'>('medium');

  // Live Swings Feed
  const [swings, setSwings] = useState<SwingEvent[]>([
    { id: '1', sport: 'Badminton', type: 'Smash', timestamp: '12:15:10', peakAcceleration: 8.8, speedMph: 148 },
    { id: '2', sport: 'Badminton', type: 'Drop Shot', timestamp: '12:15:16', peakAcceleration: 1.8, speedMph: 28 },
    { id: '3', sport: 'Badminton', type: 'Drive', timestamp: '12:15:21', peakAcceleration: 3.9, speedMph: 74 },
    { id: '4', sport: 'Badminton', type: 'Net Shot', timestamp: '12:15:25', peakAcceleration: 1.1, speedMph: 16 },
    { id: '5', sport: 'Badminton', type: 'Clear', timestamp: '12:15:30', peakAcceleration: 4.4, speedMph: 82 },
  ]);

  // Tab
  const [activeTab, setActiveTab] = useState<'scorekeeper' | 'telemetry' | 'gemini_coach' | 'history' | 'swift_stack'>('gemini_coach');

  // Gemini AI Coach Chat / Insight state
  const [coachResponse, setCoachResponse] = useState<string>(
    "🏸 [Gemini AI Coach]: Your badminton jump smashes are generating an elite 8.8G peak acceleration! However, noticing a 4:1 ratio of attacking smashes to defensive clears—ensure you save energy by mixing in deceptive cross-court drops when the opponent backs up deep."
  );
  const [isGeneratingAdvice, setIsGeneratingAdvice] = useState<boolean>(false);
  const [userQuery, setUserQuery] = useState<string>('');
  const [isLiveGemini, setIsLiveGemini] = useState<boolean>(true);

  // Match History
  const [matches] = useState<MatchRecord[]>([
    {
      id: 'm-badminton-1',
      sport: 'Badminton',
      date: 'Today, 11:15 AM',
      durationMinutes: 42,
      finalScore: '21 - 18, 22 - 20',
      won: true,
      totalSwings: 320,
      avgHeartRate: 165,
      activeCalories: 510,
      highlightStat: 'Max Smash: 154 mph (9.2 G)',
      coachInsight: 'Explosive jump smashes down the line created 11 outright winners. Keep racket head upright during net transitions.'
    },
    {
      id: 'm-pb-1',
      sport: 'Pickleball',
      date: 'Yesterday, 4:30 PM',
      durationMinutes: 31,
      finalScore: '11 - 9',
      won: true,
      totalSwings: 178,
      avgHeartRate: 148,
      activeCalories: 340,
      highlightStat: 'Dink Ratio: 44%',
      coachInsight: 'Solid NVZ patience and crisp 3rd-shot drops. Reduced unforced errors on wide backhand reaches.'
    }
  ]);

  // Timer simulation
  useEffect(() => {
    let timer: NodeJS.Timeout;
    if (isMatchActive) {
      timer = setInterval(() => {
        setMatchSeconds(prev => prev + 1);
      }, 1000);
    }
    return () => clearInterval(timer);
  }, [isMatchActive]);

  // Badminton Scoring Rules (BWF 21-point system)
  const scoreBadmintonRally = (winner: 'US' | 'THEM') => {
    setBadmintonHistory(prev => [...prev, { my: badmintonMyScore, opp: badmintonOppScore, server: badmintonServer }]);
    if (winner === 'US') {
      setBadmintonMyScore(s => s + 1);
    } else {
      setBadmintonOppScore(s => s + 1);
    }
    // In BWF rally point scoring, the rally winner serves next!
    setBadmintonServer(winner);
  };

  const undoBadmintonScore = () => {
    if (badmintonHistory.length === 0) return;
    const prev = badmintonHistory[badmintonHistory.length - 1];
    setBadmintonHistory(h => h.slice(0, -1));
    setBadmintonMyScore(prev.my);
    setBadmintonOppScore(prev.opp);
    setBadmintonServer(prev.server);
  };

  const resetBadmintonScore = () => {
    setBadmintonHistory([]);
    setBadmintonMyScore(0);
    setBadmintonOppScore(0);
    setBadmintonServer('US');
  };

  // Pickleball Scoring Rules (0-0-2)
  const scorePickleballRally = (winner: 'US' | 'THEM') => {
    setPbHistory(prev => [...prev, { my: pbMyScore, opp: pbOppScore, team: pbServingTeam, server: pbServerNumber }]);
    if (winner === pbServingTeam) {
      if (winner === 'US') setPbMyScore(s => s + 1);
      else setPbOppScore(s => s + 1);
    } else {
      // Fault
      if (pbServerNumber === 1) {
        setPbServerNumber(2);
      } else {
        setPbServingTeam(t => t === 'US' ? 'THEM' : 'US');
        setPbServerNumber(1);
      }
    }
  };

  const undoPickleballScore = () => {
    if (pbHistory.length === 0) return;
    const prev = pbHistory[pbHistory.length - 1];
    setPbHistory(h => h.slice(0, -1));
    setPbMyScore(prev.my);
    setPbOppScore(prev.opp);
    setPbServingTeam(prev.team);
    setPbServerNumber(prev.server);
  };

  const resetPickleballScore = () => {
    setPbHistory([]);
    setPbMyScore(0);
    setPbOppScore(0);
    setPbServingTeam('US');
    setPbServerNumber(2);
  };

  // BWF Service Court calculation (Even -> Right Court, Odd -> Left Court)
  const currentServerScore = badmintonServer === 'US' ? badmintonMyScore : badmintonOppScore;
  const badmintonCourt = currentServerScore % 2 === 0 ? 'Right Court (Even)' : 'Left Court (Odd)';

  // Check Game Over
  const isBadmintonGameOver = () => {
    const maxS = Math.max(badmintonMyScore, badmintonOppScore);
    const minS = Math.min(badmintonMyScore, badmintonOppScore);
    if (maxS >= 30) return true;
    if (maxS >= 21 && (maxS - minS) >= 2) return true;
    return false;
  };

  // Simulate Swing
  const simulateStroke = (stroke: SwingStroke) => {
    const isBadm = sport === 'Badminton';
    let gForce = 3.0;
    let speed = 50;

    if (isBadm) {
      switch (stroke) {
        case 'Smash':
          gForce = +(7.5 + Math.random() * 4.0).toFixed(1); // 7.5 - 11.5 G
          speed = Math.round(120 + Math.random() * 45); // 120 - 165 mph
          break;
        case 'Clear':
          gForce = +(3.8 + Math.random() * 1.5).toFixed(1);
          speed = Math.round(75 + Math.random() * 20);
          break;
        case 'Drop Shot':
          gForce = +(1.4 + Math.random() * 0.9).toFixed(1);
          speed = Math.round(25 + Math.random() * 15);
          break;
        case 'Drive':
          gForce = +(3.5 + Math.random() * 1.6).toFixed(1);
          speed = Math.round(65 + Math.random() * 20);
          break;
        case 'Net Shot':
          gForce = +(0.9 + Math.random() * 0.6).toFixed(1);
          speed = Math.round(14 + Math.random() * 10);
          break;
        default:
          gForce = +(2.4 + Math.random() * 1.2).toFixed(1);
          speed = Math.round(35 + Math.random() * 15);
      }
    } else {
      switch (stroke) {
        case 'Overhead Smash':
          gForce = +(5.0 + Math.random() * 2.0).toFixed(1);
          speed = Math.round(50 + Math.random() * 15);
          break;
        case 'Dink':
          gForce = +(1.1 + Math.random() * 0.6).toFixed(1);
          speed = Math.round(15 + Math.random() * 8);
          break;
        default:
          gForce = +(2.8 + Math.random() * 1.4).toFixed(1);
          speed = Math.round(32 + Math.random() * 12);
      }
    }

    const now = new Date();
    const timeStr = now.toTimeString().split(' ')[0];
    const newSwing: SwingEvent = {
      id: Math.random().toString(),
      type: stroke,
      sport,
      timestamp: timeStr,
      peakAcceleration: gForce,
      speedMph: speed
    };

    setSwings(prev => [newSwing, ...prev.slice(0, 19)]);
    setCalories(c => c + Math.round(gForce * (isBadm ? 1.8 : 1.2)));
    setHeartRate(h => Math.min(192, Math.max(125, h + Math.floor(Math.random() * 6 - 2))));
  };

  // Call Gemini AI Coach endpoint
  const askGeminiCoach = async (customPrompt?: string) => {
    setIsGeneratingAdvice(true);
    const targetPrompt = customPrompt || userQuery || (
      sport === 'Badminton' 
        ? `Analyze my current Badminton match stats: Score is ${badmintonMyScore}-${badmintonOppScore}, duration ${Math.floor(matchSeconds / 60)} minutes, active heart rate ${heartRate} bpm, with recent smashes peaking at 9.8G. Give me 3 concise, high-impact biomechanical and tactical coaching recommendations.`
        : `Analyze my current Pickleball match stats: Score is ${pbMyScore}-${pbOppScore}, duration ${Math.floor(matchSeconds / 60)} minutes, active heart rate ${heartRate} bpm. Provide concise tactical kitchen line and 3rd shot drop coaching advice.`
    );

    try {
      const res = await fetch('/api/coach', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          prompt: targetPrompt,
          sport
        })
      });

      if (!res.ok) {
        throw new Error(`HTTP error ${res.status}`);
      }

      const data = await res.json();
      setCoachResponse(data.insight || 'No response from AI Coach.');
      setIsLiveGemini(data.isLive !== false);
    } catch (err: any) {
      console.error(err);
      setCoachResponse(
        `🏸 [Gemini AI Coach]: Focus on fast racquet reset after deep smashes! Maintain wrist stability during defense to convert high-pressure attacks into attacking drives.`
      );
    } finally {
      setIsGeneratingAdvice(false);
      setUserQuery('');
    }
  };

  const formatTime = (totalSeconds: number) => {
    const mins = Math.floor(totalSeconds / 60);
    const secs = totalSeconds % 60;
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  };

  return (
    <div className="min-h-screen bg-neutral-950 text-neutral-100 flex flex-col font-sans">
      {/* Top Header */}
      <header className="border-b border-neutral-800/80 bg-neutral-900/70 backdrop-blur-md sticky top-0 z-30 px-4 sm:px-8 py-3.5 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-emerald-600 via-teal-500 to-cyan-400 flex items-center justify-center shadow-lg shadow-emerald-500/20 ring-1 ring-emerald-400/40">
            <Activity className="w-5 h-5 text-neutral-950 stroke-[2.5]" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-lg font-bold tracking-tight text-white">SwingFit</h1>
              <span className="text-[10px] font-semibold uppercase tracking-wider bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 px-2 py-0.5 rounded-full">
                Multi-Sport CoreMotion
              </span>
              <span className="text-[10px] font-semibold uppercase tracking-wider bg-purple-500/10 text-purple-400 border border-purple-500/30 px-2 py-0.5 rounded-full flex items-center gap-1">
                <Sparkles className="w-3 h-3 text-purple-400" />
                Gemini AI Coach
              </span>
            </div>
            <p className="text-xs text-neutral-400">watchOS & iOS Badminton & Pickleball Kinematics Engine</p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          {/* Sport Selector Pill */}
          <div className="flex items-center p-1 bg-neutral-900 border border-neutral-800 rounded-xl">
            <button
              id="sport-badminton"
              onClick={() => setSport('Badminton')}
              className={`px-3 py-1 text-xs font-bold rounded-lg transition-all flex items-center gap-1.5 ${
                sport === 'Badminton'
                  ? 'bg-gradient-to-r from-emerald-600 to-teal-600 text-white shadow-md'
                  : 'text-neutral-400 hover:text-white'
              }`}
            >
              <span>🏸</span> Badminton (BWF 21)
            </button>
            <button
              id="sport-pickleball"
              onClick={() => setSport('Pickleball')}
              className={`px-3 py-1 text-xs font-bold rounded-lg transition-all flex items-center gap-1.5 ${
                sport === 'Pickleball'
                  ? 'bg-gradient-to-r from-emerald-600 to-teal-600 text-white shadow-md'
                  : 'text-neutral-400 hover:text-white'
              }`}
            >
              <span>🥒</span> Pickleball (0-0-2)
            </button>
          </div>

          <div className="hidden md:flex items-center gap-3 text-xs text-neutral-400 border border-neutral-800 bg-neutral-900/80 px-3 py-1.5 rounded-lg font-mono">
            <span className="flex items-center gap-1 text-rose-400">
              <Heart className="w-3.5 h-3.5 fill-rose-500" />
              {heartRate} bpm
            </span>
            <span className="text-neutral-700">|</span>
            <span className="flex items-center gap-1 text-amber-400">
              <Flame className="w-3.5 h-3.5 fill-amber-500" />
              {calories} kcal
            </span>
          </div>

          <button 
            id="toggle-match-status"
            onClick={() => setIsMatchActive(!isMatchActive)}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
              isMatchActive 
                ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30 hover:bg-amber-500/30' 
                : 'bg-emerald-600 text-white hover:bg-emerald-500'
            }`}
          >
            {isMatchActive ? <Pause className="w-3.5 h-3.5" /> : <Play className="w-3.5 h-3.5" />}
            {isMatchActive ? 'Pause' : 'Resume'}
          </button>
        </div>
      </header>

      {/* Nav Tabs */}
      <div className="border-b border-neutral-800 bg-neutral-900/40 px-4 sm:px-8">
        <nav className="flex space-x-6 text-sm">
          <button 
            id="tab-gemini"
            onClick={() => setActiveTab('gemini_coach')}
            className={`py-3 font-medium transition-colors border-b-2 flex items-center gap-2 ${
              activeTab === 'gemini_coach' 
                ? 'border-purple-500 text-purple-400' 
                : 'border-transparent text-neutral-400 hover:text-neutral-200'
            }`}
          >
            <Sparkles className="w-4 h-4 text-purple-400" />
            Gemini AI Coach
          </button>
          <button 
            id="tab-scorekeeper"
            onClick={() => setActiveTab('scorekeeper')}
            className={`py-3 font-medium transition-colors border-b-2 flex items-center gap-2 ${
              activeTab === 'scorekeeper' 
                ? 'border-emerald-500 text-emerald-400' 
                : 'border-transparent text-neutral-400 hover:text-neutral-200'
            }`}
          >
            <Trophy className="w-4 h-4" />
            {sport === 'Badminton' ? 'BWF 21-pt Scorekeeper' : '0-0-2 Scorekeeper'}
          </button>
          <button 
            id="tab-telemetry"
            onClick={() => setActiveTab('telemetry')}
            className={`py-3 font-medium transition-colors border-b-2 flex items-center gap-2 ${
              activeTab === 'telemetry' 
                ? 'border-emerald-500 text-emerald-400' 
                : 'border-transparent text-neutral-400 hover:text-neutral-200'
            }`}
          >
            <Zap className="w-4 h-4" />
            50Hz Kinematics & High-G Telemetry
          </button>
          <button 
            id="tab-history"
            onClick={() => setActiveTab('history')}
            className={`py-3 font-medium transition-colors border-b-2 flex items-center gap-2 ${
              activeTab === 'history' 
                ? 'border-emerald-500 text-emerald-400' 
                : 'border-transparent text-neutral-400 hover:text-neutral-200'
            }`}
          >
            <Activity className="w-4 h-4" />
            Match Logs & History
          </button>
          <button 
            id="tab-swift"
            onClick={() => setActiveTab('swift_stack')}
            className={`py-3 font-medium transition-colors border-b-2 flex items-center gap-2 ${
              activeTab === 'swift_stack' 
                ? 'border-emerald-500 text-emerald-400' 
                : 'border-transparent text-neutral-400 hover:text-neutral-200'
            }`}
          >
            <Code2 className="w-4 h-4" />
            Native Swift / Xcode Stack
          </button>
        </nav>
      </div>

      {/* Main Container */}
      <main className="flex-1 p-4 sm:p-8 max-w-7xl w-full mx-auto space-y-6">
        {/* GEMINI AI COACH VIEW */}
        {activeTab === 'gemini_coach' && (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Main AI Coach Consultation Room */}
            <div className="lg:col-span-2 space-y-6">
              {/* Primary AI Coach Terminal */}
              <div className="bg-gradient-to-b from-neutral-900 via-neutral-900 to-neutral-950 border border-purple-500/30 rounded-2xl p-6 shadow-2xl relative overflow-hidden">
                <div className="flex items-center justify-between border-b border-neutral-800 pb-4 mb-4">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-purple-500/20 border border-purple-500/40 flex items-center justify-center">
                      <Bot className="w-5 h-5 text-purple-400" />
                    </div>
                    <div>
                      <h2 className="text-base font-bold text-white flex items-center gap-2">
                        Google Gemini AI Racket Coach
                        <span className="text-[10px] font-mono bg-purple-950/60 text-purple-300 border border-purple-800/60 px-2 py-0.5 rounded-full">
                          gemini-3.8-flash
                        </span>
                      </h2>
                      <p className="text-xs text-neutral-400">
                        {sport} Biomechanics, Shot Distribution & Tactical Strategy
                      </p>
                    </div>
                  </div>

                  <button
                    id="btn-refresh-gemini-analysis"
                    onClick={() => askGeminiCoach()}
                    disabled={isGeneratingAdvice}
                    className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold bg-purple-600 hover:bg-purple-500 text-white transition-all disabled:opacity-50"
                  >
                    {isGeneratingAdvice ? (
                      <Loader2 className="w-3.5 h-3.5 animate-spin" />
                    ) : (
                      <Sparkles className="w-3.5 h-3.5" />
                    )}
                    {isGeneratingAdvice ? 'Consulting Gemini...' : 'Analyze Match Session'}
                  </button>
                </div>

                {/* AI Advice Output Bubble */}
                <div className="bg-neutral-950/80 border border-neutral-800 rounded-xl p-5 mb-4 space-y-3">
                  <div className="flex items-center justify-between text-xs text-neutral-400">
                    <span className="font-semibold uppercase tracking-wider text-purple-400 flex items-center gap-1.5">
                      <Sparkles className="w-3.5 h-3.5" />
                      Tactical Biomechanics Insight
                    </span>
                    <span className="font-mono text-[11px] text-neutral-400">
                      {isLiveGemini ? 'Connected to Gemini API' : 'Simulated Preview Mode'}
                    </span>
                  </div>

                  <div className="text-sm text-neutral-200 leading-relaxed font-sans whitespace-pre-line">
                    {isGeneratingAdvice ? (
                      <div className="flex items-center gap-2.5 py-4 text-purple-300">
                        <Loader2 className="w-4 h-4 animate-spin text-purple-400" />
                        Analyzing sensor kinematics, smash speeds, and court movement...
                      </div>
                    ) : (
                      coachResponse
                    )}
                  </div>
                </div>

                {/* Custom Query Input */}
                <div className="space-y-3">
                  <span className="text-xs text-neutral-400 block font-medium">Ask Gemini Coach a specific question:</span>
                  <div className="flex gap-2">
                    <input
                      id="input-gemini-query"
                      type="text"
                      placeholder={
                        sport === 'Badminton'
                          ? "e.g. How can I generate more steepness on my backhand smash?"
                          : "e.g. When should I speed up a dink vs reset softly?"
                      }
                      value={userQuery}
                      onChange={(e) => setUserQuery(e.target.value)}
                      onKeyDown={(e) => { if (e.key === 'Enter' && userQuery.trim()) askGeminiCoach(); }}
                      className="flex-1 bg-neutral-950 border border-neutral-800 focus:border-purple-500 rounded-xl px-4 py-2.5 text-xs text-neutral-100 placeholder:text-neutral-400 outline-none transition-all"
                    />
                    <button
                      id="btn-send-gemini-query"
                      onClick={() => askGeminiCoach()}
                      disabled={isGeneratingAdvice || !userQuery.trim()}
                      className="px-4 py-2.5 rounded-xl bg-purple-600 hover:bg-purple-500 disabled:opacity-40 text-white text-xs font-semibold flex items-center gap-1.5 transition-all"
                    >
                      <Send className="w-3.5 h-3.5" />
                      Ask
                    </button>
                  </div>
                </div>

                {/* Quick Prompts */}
                <div className="mt-4 pt-4 border-t border-neutral-800 flex flex-wrap gap-2">
                  <span className="text-[11px] text-neutral-400 self-center">Quick drills:</span>
                  {(sport === 'Badminton' ? [
                    'Jump Smash Steepness & Recovery',
                    'High Clear vs Drop Shot Balance',
                    'Doubles Drive Attack Defenses',
                    'Footwork split-step timing'
                  ] : [
                    'Kitchen Line Resets from Drives',
                    '3rd-Shot Drop Apex Placement',
                    'Dink Patience vs Speedups',
                    'Stacking & Side-out Positioning'
                  ]).map(promptText => (
                    <button
                      key={promptText}
                      onClick={() => askGeminiCoach(`Provide elite coach advice for: ${promptText} in ${sport}.`)}
                      className="text-[11px] px-2.5 py-1 rounded-lg bg-neutral-850 hover:bg-neutral-800 border border-neutral-800 text-neutral-300 transition-all hover:border-purple-500/50"
                    >
                      {promptText}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            {/* Match Telemetry Snapshot Sidecard */}
            <div className="space-y-6">
              <div className="bg-neutral-900/60 border border-neutral-800/80 rounded-2xl p-5 space-y-4">
                <h3 className="text-sm font-semibold text-white flex items-center gap-2">
                  <Activity className="w-4 h-4 text-emerald-400" />
                  Live {sport} Match Metrics
                </h3>

                <div className="grid grid-cols-2 gap-3">
                  <div className="bg-neutral-950/70 p-3 rounded-xl border border-neutral-800">
                    <span className="text-[10px] text-neutral-400 block uppercase">Current Score</span>
                    <strong className="text-xl font-mono text-white">
                      {sport === 'Badminton' ? `${badmintonMyScore} - ${badmintonOppScore}` : `${pbMyScore} - ${pbOppScore}`}
                    </strong>
                  </div>
                  <div className="bg-neutral-950/70 p-3 rounded-xl border border-neutral-800">
                    <span className="text-[10px] text-neutral-400 block uppercase">Peak Stroke G</span>
                    <strong className="text-xl font-mono text-emerald-400">
                      {sport === 'Badminton' ? '9.8 G' : '5.8 G'}
                    </strong>
                  </div>
                  <div className="bg-neutral-950/70 p-3 rounded-xl border border-neutral-800">
                    <span className="text-[10px] text-neutral-400 block uppercase">Avg Racket Speed</span>
                    <strong className="text-xl font-mono text-cyan-400">
                      {sport === 'Badminton' ? '128 mph' : '38 mph'}
                    </strong>
                  </div>
                  <div className="bg-neutral-950/70 p-3 rounded-xl border border-neutral-800">
                    <span className="text-[10px] text-neutral-400 block uppercase">Heart Rate Zone</span>
                    <strong className="text-xl font-mono text-rose-400">
                      Zone 4 (86%)
                    </strong>
                  </div>
                </div>

                <div className="text-xs text-neutral-400 bg-neutral-950/40 p-3 rounded-xl border border-neutral-800/50 space-y-1">
                  <div className="flex justify-between">
                    <span>Active Duration:</span>
                    <strong className="text-neutral-200">{formatTime(matchSeconds)}</strong>
                  </div>
                  <div className="flex justify-between">
                    <span>Swings Tracked:</span>
                    <strong className="text-neutral-200">{swings.length + 140} strokes</strong>
                  </div>
                  <div className="flex justify-between">
                    <span>Estimated Energy:</span>
                    <strong className="text-neutral-200">{calories} kcal</strong>
                  </div>
                </div>
              </div>

              {/* Gemini Native Integration Info */}
              <div className="bg-neutral-900/60 border border-neutral-800/80 rounded-2xl p-5 space-y-3">
                <h3 className="text-sm font-semibold text-white flex items-center gap-2">
                  <Bot className="w-4 h-4 text-purple-400" />
                  Swift AISummaryService Architecture
                </h3>
                <p className="text-xs text-neutral-400 leading-relaxed">
                  In the native iOS/watchOS Swift code, <code className="text-purple-400 font-mono text-[11px]">Shared/AISummaryService.swift</code> is configured to query Google Gemini (<code className="text-purple-400 font-mono text-[11px]">gemini-3.8-flash</code>) using your <code className="text-neutral-200 font-mono text-[11px]">GEMINI_API_KEY</code>.
                </p>
                <div className="text-[11px] text-neutral-400 bg-neutral-950/60 p-2.5 rounded-lg border border-neutral-800">
                  ✅ Fully adapts coaching prompt for <strong>Badminton</strong> (jump smashes, clears, court speed) and <strong>Pickleball</strong> (kitchen resets, dinks).
                </div>
              </div>
            </div>
          </div>
        )}

        {/* SCOREKEEPER VIEW */}
        {activeTab === 'scorekeeper' && (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Score HUD */}
            <div className="lg:col-span-2 bg-neutral-900/60 border border-neutral-800/80 rounded-2xl p-6 shadow-xl flex flex-col justify-between">
              <div className="flex items-center justify-between border-b border-neutral-800 pb-4">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-lg bg-neutral-800 flex items-center justify-center">
                    <Watch className="w-4 h-4 text-emerald-400" />
                  </div>
                  <div>
                    <h2 className="text-base font-semibold text-white">
                      Apple Watch {sport} Score HUD
                    </h2>
                    <p className="text-xs text-neutral-400">
                      {sport === 'Badminton' ? 'BWF Official 21-point Rally Scoring' : 'USA Pickleball 0-0-2 Side-Out Engine'}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <span className="font-mono text-xs bg-neutral-800 px-2.5 py-1 rounded text-neutral-300">
                    ⏱ {formatTime(matchSeconds)}
                  </span>
                  <button 
                    id="btn-undo-score"
                    onClick={sport === 'Badminton' ? undoBadmintonScore : undoPickleballScore} 
                    disabled={sport === 'Badminton' ? badmintonHistory.length === 0 : pbHistory.length === 0}
                    className="p-1.5 rounded-lg border border-neutral-800 bg-neutral-800/60 text-neutral-400 hover:text-neutral-200 disabled:opacity-30 disabled:cursor-not-allowed"
                    title="Undo rally"
                  >
                    <RotateCcw className="w-4 h-4" />
                  </button>
                </div>
              </div>

              {/* Big Score Callout */}
              <div className="my-8 text-center bg-neutral-950/70 border border-neutral-800/60 rounded-xl p-8 relative overflow-hidden">
                <div className="absolute top-3 left-4 text-xs font-semibold tracking-wider text-neutral-400 uppercase">
                  {sport === 'Badminton' ? 'BWF Match Score' : 'Pickleball Callout (0-0-2)'}
                </div>

                <div className="text-6xl sm:text-7xl font-mono font-black tracking-tight text-white my-3">
                  {sport === 'Badminton' 
                    ? `${badmintonMyScore} - ${badmintonOppScore}`
                    : `${pbServingTeam === 'US' ? pbMyScore : pbOppScore} - ${pbServingTeam === 'US' ? pbOppScore : pbMyScore} - ${pbServerNumber}`
                  }
                </div>

                {sport === 'Badminton' ? (
                  <div className="flex items-center justify-center gap-4 text-xs text-neutral-300 mt-2">
                    <span>Serving Side: <strong className="text-emerald-400">{badmintonServer === 'US' ? 'US' : 'OPPONENT'}</strong></span>
                    <span>•</span>
                    <span>Service Court: <strong className="text-cyan-400">{badmintonCourt}</strong></span>
                    {isBadmintonGameOver() && (
                      <span className="bg-emerald-500/20 text-emerald-400 border border-emerald-500/40 px-2 py-0.5 rounded-full font-bold">
                        GAME OVER ({badmintonMyScore > badmintonOppScore ? 'US WON' : 'THEM WON'})
                      </span>
                    )}
                  </div>
                ) : (
                  <div className="flex items-center justify-center gap-6 text-xs text-neutral-400 mt-2">
                    <span>Serving: <strong className="text-emerald-400">{pbServingTeam === 'US' ? `US (Server ${pbServerNumber})` : `OPPONENT (Server ${pbServerNumber})`}</strong></span>
                    <span>•</span>
                    <span>Side: <strong className="text-neutral-200">{pbServingTeam === 'US' ? (pbMyScore % 2 === 0 ? 'Right (Even)' : 'Left (Odd)') : (pbOppScore % 2 === 0 ? 'Right' : 'Left')}</strong></span>
                  </div>
                )}
              </div>

              {/* Score Click Actions */}
              <div className="grid grid-cols-2 gap-4">
                <button
                  id="btn-score-us"
                  onClick={() => sport === 'Badminton' ? scoreBadmintonRally('US') : scorePickleballRally('US')}
                  className="group flex flex-col items-center justify-center p-6 rounded-xl border border-emerald-500/40 bg-emerald-950/20 hover:bg-emerald-900/30 transition-all duration-200 active:scale-95 shadow-lg shadow-emerald-950/40"
                >
                  <span className="text-xs uppercase font-bold tracking-wider text-emerald-400 mb-1">
                    US / We Won Rally
                  </span>
                  <span className="text-4xl font-extrabold font-mono text-white mb-2">
                    {sport === 'Badminton' ? badmintonMyScore : pbMyScore}
                  </span>
                  <span className="text-[11px] text-neutral-400">
                    {sport === 'Badminton' ? '+1 Point & Retain/Take Serve' : (pbServingTeam === 'US' ? '+1 Point' : 'Fault on Them')}
                  </span>
                </button>

                <button
                  id="btn-score-them"
                  onClick={() => sport === 'Badminton' ? scoreBadmintonRally('THEM') : scorePickleballRally('THEM')}
                  className="group flex flex-col items-center justify-center p-6 rounded-xl border border-rose-500/40 bg-rose-950/20 hover:bg-rose-900/30 transition-all duration-200 active:scale-95 shadow-lg shadow-rose-950/40"
                >
                  <span className="text-xs uppercase font-bold tracking-wider text-rose-400 mb-1">
                    THEM / Opponent Won Rally
                  </span>
                  <span className="text-4xl font-extrabold font-mono text-white mb-2">
                    {sport === 'Badminton' ? badmintonOppScore : pbOppScore}
                  </span>
                  <span className="text-[11px] text-neutral-400">
                    {sport === 'Badminton' ? '+1 Point & Retain/Take Serve' : (pbServingTeam === 'THEM' ? '+1 Point' : 'Fault on Us')}
                  </span>
                </button>
              </div>

              {/* Reset & Status */}
              <div className="mt-6 pt-4 border-t border-neutral-800 flex items-center justify-between text-xs text-neutral-400">
                <span>
                  {sport === 'Badminton' 
                    ? 'Played to 21 (win by 2, cap at 30).' 
                    : 'Played to 11 (win by 2).'}
                </span>
                <button 
                  id="btn-reset-match"
                  onClick={sport === 'Badminton' ? resetBadmintonScore : resetPickleballScore}
                  className="text-neutral-400 hover:text-rose-400 transition-colors flex items-center gap-1"
                >
                  <RefreshCw className="w-3 h-3" /> Reset Match
                </button>
              </div>
            </div>

            {/* Rules and Sensor Settings */}
            <div className="space-y-6">
              <div className="bg-neutral-900/60 border border-neutral-800/80 rounded-2xl p-5 space-y-3">
                <h3 className="text-sm font-semibold text-white flex items-center gap-2">
                  <ShieldAlert className="w-4 h-4 text-emerald-400" />
                  {sport === 'Badminton' ? 'BWF 21-Point Scoring Rules' : 'Pickleball State Rules'}
                </h3>
                <ul className="text-xs space-y-2 text-neutral-300">
                  {sport === 'Badminton' ? (
                    <>
                      <li className="flex items-start gap-2">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 mt-1.5 shrink-0"></span>
                        <span><strong>Rally Point Scoring:</strong> Every rally scores 1 point regardless of who served.</span>
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 mt-1.5 shrink-0"></span>
                        <span><strong>Court Alternation:</strong> Even score serves from the Right; Odd score serves from the Left.</span>
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 mt-1.5 shrink-0"></span>
                        <span><strong>Deuce & Cap:</strong> Must win by 2 points at 20-20. The 30th point is sudden death.</span>
                      </li>
                    </>
                  ) : (
                    <>
                      <li className="flex items-start gap-2">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 mt-1.5 shrink-0"></span>
                        <span><strong>0-0-2 Opening:</strong> Only 1 server for the first service turn.</span>
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 mt-1.5 shrink-0"></span>
                        <span><strong>Side-Out:</strong> Only the serving team scores points.</span>
                      </li>
                    </>
                  )}
                </ul>
              </div>

              {/* Wrist Calibration */}
              <div className="bg-neutral-900/60 border border-neutral-800/80 rounded-2xl p-5 space-y-4">
                <h3 className="text-sm font-semibold text-white flex items-center gap-2">
                  <Sliders className="w-4 h-4 text-emerald-400" />
                  Wrist & CoreMotion Sensitivity
                </h3>
                <div>
                  <label className="text-xs text-neutral-400 block mb-1.5">Dominant Racquet Hand</label>
                  <div className="grid grid-cols-2 gap-2">
                    {(['right', 'left'] as const).map(hand => (
                      <button
                        key={hand}
                        id={`calibrate-${hand}-hand`}
                        onClick={() => setHittingHand(hand)}
                        className={`px-3 py-1.5 text-xs font-semibold capitalize rounded-lg border transition-all ${
                          hittingHand === hand
                            ? 'bg-emerald-600/30 border-emerald-500 text-emerald-300'
                            : 'bg-neutral-800 border-neutral-700 text-neutral-400'
                        }`}
                      >
                        {hand} Hand
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* TELEMETRY & STROKE CLASSIFIER */}
        {activeTab === 'telemetry' && (
          <div className="space-y-6">
            <div className="bg-neutral-900/60 border border-neutral-800/80 rounded-2xl p-6 shadow-xl space-y-4">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-neutral-800 pb-4">
                <div>
                  <h2 className="text-base font-semibold text-white flex items-center gap-2">
                    <Zap className="w-4 h-4 text-emerald-400" />
                    50Hz {sport} Kinematic Stroke Classifier
                  </h2>
                  <p className="text-xs text-neutral-400">
                    Calculates angular velocity vector, radial acceleration, and stroke classification heuristics.
                  </p>
                </div>
                <span className="text-xs font-mono text-emerald-400 bg-emerald-950/40 border border-emerald-800/40 px-3 py-1 rounded-full">
                  50.0 Hz Active Sampling
                </span>
              </div>

              {/* Stroke Simulation Buttons */}
              <div className="pt-2">
                <span className="text-xs font-medium text-neutral-300 block mb-2">Simulate {sport} Stroke from Apple Watch:</span>
                <div className="flex flex-wrap gap-2.5">
                  {(sport === 'Badminton' 
                    ? (['Smash', 'Clear', 'Drop Shot', 'Drive', 'Net Shot', 'Lift', 'Serve'] as BadmintonStroke[])
                    : (['Dink', 'Forehand', 'Backhand', 'Overhead Smash', 'Serve'] as PickleballStroke[])
                  ).map(stroke => (
                    <button
                      key={stroke}
                      id={`simulate-stroke-${stroke.toLowerCase().replace(' ', '-')}`}
                      onClick={() => simulateStroke(stroke)}
                      className="px-4 py-2 rounded-xl bg-neutral-800 hover:bg-neutral-700 border border-neutral-700 text-neutral-200 text-xs font-semibold transition-all active:scale-95 flex items-center gap-2 hover:border-emerald-500/60 hover:text-white"
                    >
                      <Zap className="w-3.5 h-3.5 text-emerald-400" />
                      {stroke}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            {/* Live Swing Stream */}
            <div className="bg-neutral-900/60 border border-neutral-800/80 rounded-2xl p-6 shadow-xl space-y-4">
              <div className="flex items-center justify-between border-b border-neutral-800 pb-3">
                <h3 className="text-sm font-semibold text-white">Live Swings Feed (SwiftData Model)</h3>
                <span className="text-xs text-neutral-400">{swings.length} strokes captured</span>
              </div>

              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs">
                  <thead>
                    <tr className="border-b border-neutral-800 text-neutral-400">
                      <th className="py-2.5 font-medium">Time</th>
                      <th className="py-2.5 font-medium">Sport</th>
                      <th className="py-2.5 font-medium">Stroke Type</th>
                      <th className="py-2.5 font-medium">Peak G-Force</th>
                      <th className="py-2.5 font-medium">Racquet Speed</th>
                      <th className="py-2.5 font-medium text-right">Confidence</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-neutral-800/50">
                    {swings.map(s => (
                      <tr key={s.id} className="hover:bg-neutral-800/30">
                        <td className="py-2.5 font-mono text-neutral-400">{s.timestamp}</td>
                        <td className="py-2.5 text-neutral-300">{s.sport}</td>
                        <td className="py-2.5">
                          <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-md font-medium text-[11px] ${
                            s.type === 'Smash' || s.type === 'Overhead Smash' ? 'bg-rose-500/20 text-rose-300 border border-rose-500/30' :
                            s.type === 'Drop Shot' || s.type === 'Dink' ? 'bg-cyan-500/20 text-cyan-300 border border-cyan-500/30' :
                            s.type === 'Clear' || s.type === 'Drive' ? 'bg-purple-500/20 text-purple-300 border border-purple-500/30' :
                            'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                          }`}>
                            {s.type}
                          </span>
                        </td>
                        <td className="py-2.5 font-mono text-neutral-200">{s.peakAcceleration} G</td>
                        <td className="py-2.5 font-mono text-neutral-200">{s.speedMph} mph</td>
                        <td className="py-2.5 text-right font-mono text-emerald-400">96.4%</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* MATCH HISTORY */}
        {activeTab === 'history' && (
          <div className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {matches.map(m => (
                <div key={m.id} className="bg-neutral-900/60 border border-neutral-800/80 rounded-2xl p-5 space-y-4 shadow-lg">
                  <div className="flex items-center justify-between border-b border-neutral-800 pb-3">
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-xs font-semibold text-emerald-400 bg-emerald-950/50 px-2 py-0.5 rounded">
                          {m.sport}
                        </span>
                        <span className="text-xs text-neutral-400">{m.date}</span>
                      </div>
                      <h4 className="text-lg font-bold text-white mt-1">{m.finalScore}</h4>
                    </div>
                    <span className="bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 px-2.5 py-1 rounded-full text-xs font-bold uppercase tracking-wider">
                      {m.won ? 'VICTORY' : 'DEFEAT'}
                    </span>
                  </div>

                  <div className="grid grid-cols-3 gap-2 text-center text-xs">
                    <div className="bg-neutral-950/60 p-2.5 rounded-lg border border-neutral-800/60">
                      <span className="text-neutral-400 block text-[10px]">DURATION</span>
                      <strong className="text-white text-sm">{m.durationMinutes}m</strong>
                    </div>
                    <div className="bg-neutral-950/60 p-2.5 rounded-lg border border-neutral-800/60">
                      <span className="text-neutral-400 block text-[10px]">SWINGS</span>
                      <strong className="text-white text-sm">{m.totalSwings}</strong>
                    </div>
                    <div className="bg-neutral-950/60 p-2.5 rounded-lg border border-neutral-800/60">
                      <span className="text-neutral-400 block text-[10px]">TOP METRIC</span>
                      <strong className="text-emerald-400 text-xs font-mono">{m.highlightStat}</strong>
                    </div>
                  </div>

                  <div className="bg-neutral-950/40 p-3 rounded-xl border border-neutral-800/50 flex items-start gap-2.5">
                    <Bot className="w-4 h-4 text-purple-400 shrink-0 mt-0.5" />
                    <p className="text-xs text-neutral-300 italic">
                      "{m.coachInsight}"
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* NATIVE SWIFT STACK INSPECTOR */}
        {activeTab === 'swift_stack' && (
          <div className="space-y-6">
            <div className="bg-neutral-900/60 border border-neutral-800/80 rounded-2xl p-6 shadow-xl space-y-4">
              <div className="flex items-center justify-between border-b border-neutral-800 pb-3">
                <div className="flex items-center gap-2.5">
                  <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                  <h2 className="text-base font-semibold text-white">Native Apple Swift / Xcode Architecture</h2>
                </div>
                <span className="text-xs bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 px-2.5 py-1 rounded-full font-medium">
                  Badminton & Gemini Integrated
                </span>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2">
                <div className="bg-neutral-950/60 p-4 rounded-xl border border-neutral-800/80 space-y-2">
                  <h4 className="text-xs font-bold uppercase tracking-wider text-emerald-400">Shared Domain & Sports Models</h4>
                  <ul className="text-xs font-mono space-y-1.5 text-neutral-300">
                    <li className="text-purple-300">✨ Shared/Models/SportType.swift (Badminton & Pickleball)</li>
                    <li className="text-purple-300">✨ Shared/BadmintonScore.swift (BWF 21-pt Engine)</li>
                    <li>📁 Shared/PickleballScore.swift (0-0-2 Engine)</li>
                    <li>📁 Shared/Models/Match.swift (Sport + Badminton counts)</li>
                    <li>📁 Shared/Models/Swing.swift (Badminton strokes added)</li>
                  </ul>
                </div>

                <div className="bg-neutral-950/60 p-4 rounded-xl border border-neutral-800/80 space-y-2">
                  <h4 className="text-xs font-bold uppercase tracking-wider text-purple-400">Gemini AI Coach & Sensor Engine</h4>
                  <ul className="text-xs font-mono space-y-1.5 text-neutral-300">
                    <li className="text-purple-300">🤖 Shared/AISummaryService.swift (Google Gemini gemini-3.8-flash)</li>
                    <li className="text-purple-300">⚡ SwingFitWatch/Managers/MotionManager.swift (Badminton 8-15G)</li>
                    <li>📁 Tests/BadmintonScoreTests.swift (BWF Rule verification)</li>
                    <li>📁 SwingFit/Info.plist (GEMINI_API_KEY support)</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
