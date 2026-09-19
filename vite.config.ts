import { defineConfig, Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { GoogleGenAI } from '@google/genai';

function geminiCoachPlugin(): Plugin {
  let aiClient: GoogleGenAI | null = null;
  
  function getAI(): GoogleGenAI {
    const key = process.env.GEMINI_API_KEY;
    if (!key) {
      throw new Error('GEMINI_API_KEY is not configured');
    }
    if (!aiClient) {
      aiClient = new GoogleGenAI({ apiKey: key });
    }
    return aiClient;
  }

  return {
    name: 'gemini-coach-api',
    configureServer(server) {
      server.middlewares.use('/api/coach', async (req, res) => {
        if (req.method !== 'POST') {
          res.statusCode = 405;
          res.end(JSON.stringify({ error: 'Method not allowed' }));
          return;
        }

        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', async () => {
          try {
            const data = JSON.parse(body || '{}');
            const prompt = data.prompt || 'Give me tactical coaching advice for my match.';
            const sport = data.sport || 'Badminton';

            const apiKey = process.env.GEMINI_API_KEY;
            if (!apiKey) {
              res.setHeader('Content-Type', 'application/json');
              const fallbackAdvice = sport === 'Badminton' 
                ? "Your high-speed smash reached impressive peak G-forces! To improve consistency, ensure your non-racket arm points at the shuttlecock during preparation to stabilize your core before the jump. (Tip: Set GEMINI_API_KEY in environment variables for live Gemini 2.5/3 neural coaching)."
                : "Your dink patience at the kitchen line is developing well. Focus on maintaining a relaxed grip (3/10 firmness) on soft resets to absorb heavy drives into the kitchen. (Tip: Set GEMINI_API_KEY in environment variables for live Gemini 2.5/3 neural coaching).";
              res.end(JSON.stringify({
                insight: fallbackAdvice,
                model: 'gemini-3.8-flash (simulated mode)',
                isLive: false
              }));
              return;
            }

            const ai = getAI();
            const response = await ai.models.generateContent({
              model: 'gemini-3.8-flash',
              contents: prompt,
              config: {
                systemInstruction: `You are an elite, Olympic-level racket sports biomechanics coach specializing in ${sport}. You analyze sensor telemetry (gyroscope rotation, peak G-forces, shot distributions, and match scores). Provide concise, motivating, and mathematically sound tactical/biomechanical feedback in 2-4 sentences.`
              }
            });

            res.setHeader('Content-Type', 'application/json');
            res.end(JSON.stringify({
              insight: response.text,
              model: 'gemini-3.8-flash',
              isLive: true
            }));
          } catch (err: any) {
            res.statusCode = 500;
            res.setHeader('Content-Type', 'application/json');
            res.end(JSON.stringify({ error: err.message || 'Error processing coaching request' }));
          }
        });
      });
    }
  };
}

export default defineConfig({
  plugins: [react(), tailwindcss(), geminiCoachPlugin()],
  server: {
    port: 3000,
    host: '0.0.0.0',
  },
});
