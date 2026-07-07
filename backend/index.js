const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-custom-gemini-key, x-custom-openrouter-key',
  'Access-Control-Max-Age': '86400',
};

let jwksCache = null;
let jwksCacheTime = 0;

// Helper to decode Base64url
function base64urlDecode(str) {
  str = str.replace(/-/g, '+').replace(/_/g, '/');
  while (str.length % 4) {
    str += '=';
  }
  const binary = atob(str);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

// Helper to decode JWT parts
function decodeJwt(token) {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('Invalid JWT format');
  }
  const header = JSON.parse(new TextDecoder().decode(base64urlDecode(parts[0])));
  const payload = JSON.parse(new TextDecoder().decode(base64urlDecode(parts[1])));
  return { header, payload, parts };
}

// Fetch Google JWKS
async function getJwks() {
  const now = Date.now();
  if (jwksCache && (now - jwksCacheTime < 3600000)) {
    return jwksCache;
  }
  const res = await fetch('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com');
  if (!res.ok) {
    throw new Error('Failed to fetch JWKS from Google');
  }
  jwksCache = await res.json();
  jwksCacheTime = now;
  return jwksCache;
}

// Verify Firebase ID Token
async function verifyFirebaseToken(token, projectId) {
  const { header, payload, parts } = decodeJwt(token);
  
  const now = Math.floor(Date.now() / 1000);
  if (payload.exp && payload.exp < now) {
    throw new Error('Token is expired');
  }
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new Error('Invalid token issuer');
  }
  if (payload.aud !== projectId) {
    throw new Error('Invalid token audience');
  }
  
  const jwks = await getJwks();
  const jwk = jwks.keys.find(k => k.kid === header.kid);
  if (!jwk) {
    throw new Error('JWK public key not found for kid');
  }
  
  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256'
    },
    false,
    ['verify']
  );
  
  const encoder = new TextEncoder();
  const data = encoder.encode(`${parts[0]}.${parts[1]}`);
  const signature = base64urlDecode(parts[2]);
  
  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    signature,
    data
  );
  
  if (!valid) {
    throw new Error('Invalid signature');
  }
  
  return payload;
}

// Helper to convert PEM private key to ArrayBuffer for Web Crypto
function pemToArrayBuffer(pem) {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

// Exchange Google Service Account for Google OAuth Access Token
async function getGoogleAccessToken(serviceAccountJson) {
  const sa = JSON.parse(serviceAccountJson);
  const privateKeyBuffer = pemToArrayBuffer(sa.private_key);
  
  const key = await crypto.subtle.importKey(
    'pkcs8',
    privateKeyBuffer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256'
    },
    false,
    ['sign']
  );
  
  const header = { alg: 'RS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/identitytoolkit',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now
  };
  
  const encoder = new TextEncoder();
  const stringify = (obj) => btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  
  const partialToken = `${stringify(header)}.${stringify(payload)}`;
  const signatureBuffer = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    encoder.encode(partialToken)
  );
  
  const signature = btoa(String.fromCharCode(...new Uint8Array(signatureBuffer)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
    
  const assertion = `${partialToken}.${signature}`;
  
  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${assertion}`
  });
  
  if (!tokenRes.ok) {
    throw new Error(`Google OAuth token exchange failed: ${await tokenRes.text()}`);
  }
  
  const tokenData = await tokenRes.json();
  return tokenData.access_token;
}

// Robust JSON extraction from LLM response
function safeParseAiJson(raw) {
  try {
    const jsonPattern = /\{[\s\S]*\}/;
    const match = raw.match(jsonPattern);
    if (!match) return null;
    return JSON.parse(match[0]);
  } catch (_) {
    return null;
  }
}

// Build Prompt
function buildPrompt(action, data) {
  if (action === 'analyzeJobDescription') {
    const { jobDescription } = data;
    if (!jobDescription) throw new Error('Missing jobDescription');
    return `You are an expert Technical Recruiter, Resume Strategist, and ATS (Applicant Tracking System) Optimization Engineer with 15+ years of experience placing candidates at Tier-1 technology companies.
Your task is to analyze the targeted role or job description (JD) with extreme precision and perform a deep recruiter audit/breakdown to help construct a stellar resume.

Input Target Role or Job Description:
"""
${jobDescription}
"""

Instructions:
1. **Analyze target role title**: Extract the precise, standard industry job title (e.g., "Senior Full-Stack Engineer" rather than a generic or internal title like "Software Engineer II").
2. **Determine experience level**: Calibrate the seniority based on indicators like years of experience required, scope of ownership, leadership requirements, and titles mentioned. Classify strictly as "junior", "mid", or "senior".
3. **Identify required skills**: Extract all explicit and hard skills required to perform the job, including programming languages, frameworks, developer tools, database systems, APIs, cloud environments, and core concepts. Do not list generic interpersonal qualities.
4. **Identify preferred skills**: Extract nice-to-have skills, secondary technologies, optional experience, certifications, or specialized domain expertise mentioned as a plus or preferred.
5. **Extract ATS keywords**: Identify the exact technical terminology, methodologies (e.g., Agile, CI/CD, TDD), standards, and systems that recruiters search for or ATS software scans for. Be comprehensive.
6. **Identify domain keywords**: Pinpoint the business context, industry vertical, and operational domains (e.g., "SaaS", "FinTech", "Distributed Systems", "E-commerce", "High-Frequency Trading", "Mobile Application Development").
7. **Extract Non-Negotiable Skills**: The fundamental technical and soft skills strictly required to pass the initial screening.
8. **Extract High-Demand/Trending Skills**: The specific tools, frameworks, or methodologies (e.g., cloud platforms, RAG architectures) that are currently booming in this space and will make a candidate stand out.
9. **Identify Company Problems**: What are the underlying problems a company is trying to solve by hiring for this role? What values or solutions does this role bring?
10. **Identify Cultural & Operational Traits**: What cultural or operational traits (e.g., bias for action, agile delivery, product thinking, deep ownership) do companies usually value for this specific position?
11. **Generate Top Keywords/Phrases**: The exact terminology ATS (Applicant Tracking Systems) and recruiters will be scanning for (Top 3-5).
12. **Provide High-Impact Bullet Points**: Provide exactly 3 examples of how to phrase experience for this role using the "Action + Context + Metric/Result" format. Use realistic accomplishments.
13. **Recommend Standout Projects**: Recommend 2-3 types of portfolio projects that would perfectly demonstrate competence for this specific role.
14. **Generate Resume Strategy**: Provide a concise, well-researched 40-50 words strategic paragraph detailing the resume positioning, core value proposition, and key areas of impact to highlight for this specific role or job description to make the candidate stand out.

Return ONLY a valid JSON object matching this exact schema (do not wrap in markdown code blocks, do not return any other text, only the raw JSON block):
{
  "role": "string (job title)",
  "experienceLevel": "junior | mid | senior",
  "requiredSkills": ["skill1", "skill2", "skill3"],
  "preferredSkills": ["skill1", "skill2"],
  "keywords": ["keyword1", "keyword2", "keyword3"],
  "domainKeywords": ["domain1", "domain2"],
  "nonNegotiableSkills": ["skill1", "skill2"],
  "highDemandSkills": ["skill1", "skill2"],
  "companyProblems": ["problem1", "problem2"],
  "companyTraits": ["trait1", "trait2"],
  "topKeywords": ["kw1", "kw2"],
  "highImpactBullets": ["bullet1", "bullet2", "bullet3"],
  "standoutProjects": ["proj1", "proj2"],
  "roleStrategy": "string (40-50 words of resume strategy)"
}`;
  }

  if (action === 'rewriteProjectBullets') {
    const { projectTitle, projectDescription = '', technologies = [], targetRole, keywords = [], linkedSkills = [] } = data;
    if (!projectTitle || !targetRole) {
      throw new Error('Missing required fields for rewriteProjectBullets');
    }
    const skillsPrompt = linkedSkills.length > 0
        ? `Linked skills to naturally incorporate and highlight: ${linkedSkills.join(', ')}\n`
        : '';
    return `You are a Senior Product & Resume Designer with 15+ years of experience optimizing candidates for Tier-1 technology companies.
Your task is to rewrite the project/research description into exactly 3 ATS-optimized professional resume bullet points.

Target Role: ${targetRole}
Project Title: ${projectTitle}
Description / Raw Input: ${projectDescription}
Technologies / Tech Stack: ${technologies.join(', ')}
${skillsPrompt}
Keywords to naturally incorporate (crucial for passing ATS filters): ${keywords.slice(0, 10).join(', ')}

Strict Prompting Rules:
1. **Exactly 3 Bullet Points**: You must generate exactly 3 bullet points. No more, no less.
2. **Absolute Authenticity & No Fictional Content**: Base the bullet points strictly on the user's raw input description. **NEVER fabricate fake features, metrics, business scale, or outcomes** that are not stated in the raw input. Do not make up achievements or numbers (e.g. do not say "boosted revenue by 40%" or "scaled to 1M users" unless the user's input explicitly states that).
3. **Context + Tech Stack + Outcome Formula**: Every bullet point must tell a complete, structured story. Weave the technologies, libraries, or tools used directly into the action.
   - Format: [Strong Action Verb] + [What you built/engineered/implemented using specific tech/tools] + [Why/Outcome].
   - Example: "Engineered a microcontroller-based node system using ESP32 and Arduino, integrating relay modules to automate hardware recovery and reduce system downtime."
4. **Vocabulary & Keyword Alignment**: Rephrase the candidate's actual work using high-impact, professional, ATS-optimized vocabulary that aligns with the target role and naturally incorporates relevant keywords from the list above. Change the phrasing, not the facts (e.g. translate "wrote python code to read data" to "Developed automated Python scripts to parse and process datasets").
5. **Translate Research into Hard Skills**: If the project represents academic research, translate the abstract theory into concrete technical application. Detail the engineering methodology, dataset parsing, and programming tools used (e.g. Python, Pandas, PyTorch).
6. **Clean ATS Formatting**: Keep the language professional, direct, and human-designed. Do not use special formatting symbols, emojis, or vague corporate clichés ("Built a simple app", "Helped team do X").
7. **No Fake Tech**: Never mention tools or tech stacks that are not explicitly relevant or listed in the inputs.

Return ONLY valid JSON with this exact structure:
{
  "bullets": [
    "Bullet point 1 detailing technical execution and outcomes",
    "Bullet point 2 detailing tech stack application and metrics",
    "Bullet point 3 detailing additional system integration and results"
  ],
  "selectedSkills": ["skill 1", "skill 2", "skill 3"]
}`;
  }

  if (action === 'generateProfessionalSummary') {
    const { candidateBackground, targetRole, keywords = [], topSkills = [] } = data;
    if (!candidateBackground || !targetRole) {
      throw new Error('Missing required fields for generateProfessionalSummary');
    }
    return `You are a professional ATS resume writer. Write an optimized professional summary for a resume.

Target Role: ${targetRole}
Candidate Background/Context: ${candidateBackground}
Key Skills to Naturally Highlight: ${topSkills.slice(0, 6).join(', ')}
ATS Keywords to Naturally Incorporate: ${keywords.slice(0, 6).join(', ')}

Strict Guidelines:

Things to Consider (The Do's):
1. **Lead with Your Professional Identity**: Start strong by defining the candidate's professional identity and experience level. State the core focus right away (e.g., data engineering, full-stack development, AI/ML integration).
2. **Highlight Your Core Stack**: Mention specific, high-demand technologies the candidate excels in. Specifically name the strongest tools (e.g., Flutter, Next.js, PySpark, etc.) rather than generic terms.
3. **Showcase Quantifiable Achievements**: Whenever possible, point to the results of their work (e.g. optimized a data pipeline, launched an application serving a specific user base). Action-driven results are highly persuasive.
4. **Tailor for the Target Role**: Emphasize technical skills and focus areas that directly align with the target role: ${targetRole}.
5. **Keep it Concise**: Aim for exactly 3 to 5 sentences. Keep it easily skimmable.

Things to Avoid (The Don'ts):
1. **Avoid First-Person Pronouns**: NEVER use first-person pronouns like "I", "me", "my", or "we". Write in active professional voice (e.g., "Developed an AI-driven travel platform..." instead of "I developed...").
2. **Skip the Fluff and Clichés**: Avoid generic terms like "hard worker", "team player", "highly motivated", or "detail-oriented". Let projects and experiences demonstrate these traits.
3. **Don't List Everything**: Do not turn the summary into a skills dump or list every single tool or library. Highlight only the primary core stack.
4. **Avoid the Traditional "Objective Statement"**: Do not state what the candidate wants from the company. Focus entirely on the value and solutions they provide.
5. **Don't Exaggerate**: Keep every claim professional, realistic, and strictly backed by their background.

Return ONLY valid JSON:
{
  "summary": "Your generated professional summary here."
}`;
  }

  if (action === 'generateAuthenticSummary') {
    const { name, currentRole, skills = [], experience = [], education = [], projects = [], certifications = [], achievements = [], currentSummary = '' } = data;
    if (!name || !currentRole) {
      throw new Error('Missing required fields for generateAuthenticSummary');
    }

    const expList = experience.map((e) => {
      const role = e.role || '';
      const company = e.company || '';
      const duration = e.duration || '';
      const bullets = Array.isArray(e.bullets) ? e.bullets.join('; ') : '';
      return `- ${role} at ${company} (${duration}): ${bullets}`;
    }).join('\n');

    const projList = projects.map((p) => {
      const title = p.title || '';
      const tech = Array.isArray(p.technologies) ? p.technologies.join(', ') : '';
      const bullets = Array.isArray(p.bullets) ? p.bullets.join('; ') : '';
      return `- ${title} (Tech: ${tech}): ${bullets}`;
    }).join('\n');

    const eduList = education.map((e) => {
      const degree = e.degree || '';
      const inst = e.institution || '';
      const spec = e.specialisation || e.field || '';
      const years = `${e.startYear || ''} - ${e.endYear || ''}`;
      const grade = e.cgpa || e.percentage || '';
      return `- ${degree} in ${spec} from ${inst} (${years}), Grade: ${grade}`;
    }).join('\n');

    const certsList = certifications.map((c) => `- ${c.title || ''} from ${c.issuer || ''} (${c.date || ''})`).join('\n');
    const achsList = achievements.map((a) => `- ${a.title || ''}`).join('\n');

    return `Write a highly professional, realistic, and authentic professional summary for a candidate's resume/profile.
The summary must be strictly between 100 and 150 words in length.

Candidate Background:
- Name: ${name}
- Headline / Target Role: ${currentRole}
- Existing Summary (if any): ${currentSummary}

Key Skills:
${skills.join(', ')}

Work Experience:
${expList}

Projects:
${projList}

Education:
${eduList}

Certifications:
${certsList}

Achievements:
${achsList}

Strict Guidelines:

Things to Consider (The Do's):
1. **Lead with Your Professional Identity**: Start strong by defining the candidate's professional identity and experience level. State the core focus right away (e.g., data engineering, full-stack development, AI/ML integration).
2. **Highlight Your Core Stack**: Mention specific, high-demand technologies the candidate excels in. Specifically name their strongest tools (e.g., Flutter, Next.js, PySpark, etc.) rather than generic terms.
3. **Showcase Quantifiable Achievements**: Point to the results of their work based on the provided experience and projects. Action-driven results are highly persuasive.
4. **Tailor for the Target Role**: Emphasize technical skills and focus areas that directly align with the target role: ${currentRole}.
5. **Keep it Concise**: Aim for exactly 3 to 5 sentences. Keep it easily skimmable.

Things to Avoid (The Don'ts):
1. **Avoid First-Person Pronouns**: NEVER use first-person pronouns like "I", "me", "my", or "we". Write in active professional voice (e.g., starting with the role name, like "Software engineer building..." or "Backend developer focusing on..."). Do not use third-person biography pronouns ("he", "she", "they").
2. **Skip the Fluff and Clichés**: Avoid generic terms like "hard worker", "team player", "highly motivated", "results-driven", or "detail-oriented". Let projects and experiences demonstrate these traits naturally.
3. **Don't List Everything**: Do not turn the summary into a skills dump. Highlight only their primary core stack.
4. **Avoid the Traditional "Objective Statement"**: Do not state what the candidate wants from the company. Focus entirely on the value and solutions they provide.
5. **Don't Exaggerate**: Do not fabricate or exaggerate numbers, metrics, or experiences.

Return ONLY valid JSON:
{
  "summary": "Your generated authentic professional summary here."
}`;
  }

  throw new Error(`Unsupported action: ${action}`);
}

// Generate AI core execution logic
async function generateAI(prompt, customGeminiKey, customOpenRouterKey, env) {
  const activeGeminiKey = customGeminiKey || env.GEMINI_API_KEY;
  let primaryError = null;

  if (activeGeminiKey) {
    try {
      const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${activeGeminiKey}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text: prompt
                }
              ]
            }
          ],
          generationConfig: {
            temperature: 0.3,
            topK: 40,
            topP: 0.95,
            maxOutputTokens: 2048,
            responseMimeType: 'application/json'
          }
        })
      });

      if (response.ok) {
        const resJson = await response.json();
        const text = resJson.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text) {
          const parsed = safeParseAiJson(text);
          if (parsed) return parsed;
        }
      } else {
        const errText = await response.text();
        primaryError = `Gemini API returned status ${response.status}: ${errText}`;
      }
    } catch (e) {
      primaryError = e.message || e.toString();
    }
  } else {
    primaryError = 'No Gemini API key available';
  }

  console.log(`Primary Gemini generation failed: ${primaryError}. Trying OpenRouter fallback...`);

  const activeOpenRouterKey = customOpenRouterKey || env.OPENROUTER_API_KEY;
  if (!activeOpenRouterKey) {
    throw new Error(`AI generation failed. Primary Gemini error: ${primaryError}. Fallback OpenRouter error: No OpenRouter API key available.`);
  }

  try {
    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${activeOpenRouterKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://resumeos.com',
        'X-Title': 'ResumeOS',
      },
      body: JSON.stringify({
        model: 'anthropic/claude-3-haiku',
        messages: [
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.3,
        max_tokens: 2048
      })
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`OpenRouter API returned status ${response.status}: ${errText}`);
    }

    const resJson = await response.json();
    const text = resJson.choices?.[0]?.message?.content || '{}';
    const parsed = safeParseAiJson(text);
    if (!parsed) {
      throw new Error('Failed to parse OpenRouter response as JSON');
    }
    return parsed;
  } catch (openRouterError) {
    throw new Error(`AI generation failed. Primary Gemini error: ${primaryError}. Fallback OpenRouter error: ${openRouterError.message || openRouterError}`);
  }
}

// Utility to delete all user Firestore documents & subcollections
async function deleteUserFirestoreData(uid, adminToken, projectId) {
  const subcollections = [
    'skills',
    'education',
    'experience',
    'certifications',
    'achievements',
    'resumes',
    'projects',
  ];

  for (const sub of subcollections) {
    try {
      const listUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${uid}/${sub}`;
      const listRes = await fetch(listUrl, {
        headers: { 'Authorization': `Bearer ${adminToken}` }
      });
      if (listRes.ok) {
        const listData = await listRes.json();
        const documents = listData.documents || [];
        for (const doc of documents) {
          const deleteUrl = `https://firestore.googleapis.com/v1/${doc.name}`;
          await fetch(deleteUrl, {
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${adminToken}` }
          });
        }
      }
    } catch (e) {
      console.error(`Failed to delete subcollection ${sub} for user ${uid}:`, e);
    }
  }

  // Delete primary user document
  const deleteUserUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${uid}`;
  await fetch(deleteUserUrl, {
    method: 'DELETE',
    headers: { 'Authorization': `Bearer ${adminToken}` }
  });
}

// Scheduled Auto-Cleanup (CRON)
async function performCronCleanup(env) {
  const projectId = env.FIREBASE_PROJECT_ID || 'smartresume-7601e';
  const serviceAccountJson = env.FIREBASE_SERVICE_ACCOUNT_JSON;
  
  if (!serviceAccountJson) {
    console.error('CRON Warning: FIREBASE_SERVICE_ACCOUNT_JSON not set. Cleanup skipped.');
    return;
  }
  
  try {
    const token = await getGoogleAccessToken(serviceAccountJson);
    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    
    // Query Firestore unverified users who signed up > 10 minutes ago
    const queryUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
    const queryBody = {
      structuredQuery: {
        from: [{ collectionId: 'users' }],
        where: {
          compositeFilter: {
            op: 'AND',
            filters: [
              {
                fieldFilter: {
                  field: { fieldPath: 'isEmailVerified' },
                  op: 'EQUAL',
                  value: { booleanValue: false }
                }
              },
              {
                fieldFilter: {
                  field: { fieldPath: 'createdAt' },
                  op: 'LESS_THAN',
                  value: { timestampValue: tenMinutesAgo }
                }
              }
            ]
          }
        }
      }
    };
    
    const queryRes = await fetch(queryUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(queryBody)
    });
    
    if (!queryRes.ok) {
      throw new Error(`Firestore query failed: ${await queryRes.text()}`);
    }
    
    const results = await queryRes.json();
    console.log(`CRON: Found ${Array.isArray(results) ? results.length : 0} candidate entries.`);
    
    for (const item of results) {
      const doc = item.document;
      if (!doc || !doc.name) continue;
      
      // Document name looks like "projects/smartresume-7601e/databases/(default)/documents/users/UID"
      const parts = doc.name.split('/');
      const uid = parts[parts.length - 1];
      
      console.log(`CRON: Purging unverified user ${uid}...`);
      
      // 1. Delete from Firebase Authentication Admin API
      const deleteAuthUrl = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:batchDelete`;
      const authDeleteRes = await fetch(deleteAuthUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ localIds: [uid], force: true })
      });
      
      if (authDeleteRes.ok) {
        console.log(`CRON: Successfully deleted auth record for ${uid}`);
      } else {
        console.warn(`CRON Warning: Failed to delete auth record for ${uid}: ${await authDeleteRes.text()}`);
      }
      
      // 2. Delete Firestore profile document
      const deleteDocUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${uid}`;
      const docDeleteRes = await fetch(deleteDocUrl, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      
      if (docDeleteRes.ok) {
        console.log(`CRON: Successfully deleted Firestore user document ${uid}`);
      } else {
        console.warn(`CRON Warning: Failed to delete Firestore document for ${uid}: ${await docDeleteRes.text()}`);
      }
    }
    
  } catch (error) {
    console.error(`CRON Error: ${error.stack || error}`);
  }
}

export default {
  // CRON Trigger Entry Point
  async scheduled(event, env, ctx) {
    ctx.waitUntil(performCronCleanup(env));
  },

  // HTTP Request Entry Point
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: corsHeaders
      });
    }

    try {
      const url = new URL(request.url);
      const projectId = env.FIREBASE_PROJECT_ID || 'smartresume-7601e';

      // Route 1: Send verification email with 6-digit OTP
      if (url.pathname === '/v1/auth/send-otp') {
        if (request.method !== 'POST') {
          return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
            status: 405,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const authHeader = request.headers.get('Authorization') || '';
        if (!authHeader.startsWith('Bearer ')) {
          return new Response(JSON.stringify({ error: 'Missing or invalid Authorization header' }), {
            status: 401,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const token = authHeader.substring(7);
        let payload;
        try {
          payload = await verifyFirebaseToken(token, projectId);
        } catch (authError) {
          return new Response(JSON.stringify({ error: `Authentication failed: ${authError.message}` }), {
            status: 403,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const uid = payload.sub;
        const email = payload.email;

        if (!email) {
          return new Response(JSON.stringify({ error: 'Email address not found in Auth token' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        // Generate a 6-digit cryptographic OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = Math.floor(Date.now() / 1000) + 600; // 10 minutes from now

        // Get Service Account Token to write OTP securely to Firestore
        const saJson = env.FIREBASE_SERVICE_ACCOUNT_JSON;
        if (!saJson) {
          return new Response(JSON.stringify({ error: 'Service account credentials missing on server' }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const adminToken = await getGoogleAccessToken(saJson);

        // Write OTP code to /users/{uid}/verification/otp Firestore nested path
        const patchUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${uid}/verification/otp?updateMask.fieldPaths=code&updateMask.fieldPaths=expiresAt`;
        const patchBody = {
          fields: {
            code: { stringValue: otp },
            expiresAt: { integerValue: expiresAt.toString() }
          }
        };

        const patchRes = await fetch(patchUrl, {
          method: 'PATCH',
          headers: {
            'Authorization': `Bearer ${adminToken}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(patchBody)
        });

        if (!patchRes.ok) {
          return new Response(JSON.stringify({ error: `Failed to store OTP in Firestore: ${await patchRes.text()}` }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        // Send Email via Resend API
        const resendKey = env.RESEND_API_KEY;
        if (!resendKey) {
          return new Response(JSON.stringify({ error: 'Email provider credentials missing on server' }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const emailRes = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${resendKey}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            from: 'ResumeOS <onboarding@resend.dev>',
            to: [email],
            subject: 'Verify Your ResumeOS Account',
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; borderRadius: 8px;">
                <h2 style="color: #8B6B58; text-align: center;">Verify Your ResumeOS Account</h2>
                <p>Hello,</p>
                <p>Thank you for signing up for ResumeOS! To complete your registration and proceed to the onboarding checklist, please enter the 6-digit One-Time Password (OTP) below within the next 10 minutes:</p>
                <div style="background-color: #f5f5f5; border-radius: 8px; padding: 15px; text-align: center; margin: 20px 0;">
                  <span style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #333;">${otp}</span>
                </div>
                <p style="color: #666; font-size: 12px; text-align: center;">This code will expire in 10 minutes. If you did not register for this account, please ignore this email or contact support.</p>
              </div>
            `
          })
        });

        if (!emailRes.ok) {
          return new Response(JSON.stringify({ error: `Failed to dispatch email: ${await emailRes.text()}` }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        return new Response(JSON.stringify({ success: true, message: 'OTP verification code dispatched to email' }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Route 2: Verify entered 6-digit OTP
      if (url.pathname === '/v1/auth/verify-otp') {
        if (request.method !== 'POST') {
          return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
            status: 405,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const authHeader = request.headers.get('Authorization') || '';
        if (!authHeader.startsWith('Bearer ')) {
          return new Response(JSON.stringify({ error: 'Missing or invalid Authorization header' }), {
            status: 401,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const token = authHeader.substring(7);
        let payload;
        try {
          payload = await verifyFirebaseToken(token, projectId);
        } catch (authError) {
          return new Response(JSON.stringify({ error: `Authentication failed: ${authError.message}` }), {
            status: 403,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const uid = payload.sub;
        let body;
        try {
          body = await request.json();
        } catch (_) {
          return new Response(JSON.stringify({ error: 'Malformed JSON body' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const { code } = body;
        if (!code || code.length !== 6) {
          return new Response(JSON.stringify({ error: 'Verification code must be exactly 6 digits' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const saJson = env.FIREBASE_SERVICE_ACCOUNT_JSON;
        if (!saJson) {
          return new Response(JSON.stringify({ error: 'Service account credentials missing on server' }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const adminToken = await getGoogleAccessToken(saJson);

        // Fetch OTP from Firestore
        const fetchUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${uid}/verification/otp`;
        const fetchRes = await fetch(fetchUrl, {
          headers: { 'Authorization': `Bearer ${adminToken}` }
        });

        if (!fetchRes.ok) {
          return new Response(JSON.stringify({ error: 'Verification code expired or not requested' }), {
            status: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const otpDoc = await fetchRes.json();
        const storedCode = otpDoc.fields?.code?.stringValue;
        const expiresAt = parseInt(otpDoc.fields?.expiresAt?.integerValue || '0', 10);
        const now = Math.floor(Date.now() / 1000);

        if (now > expiresAt) {
          return new Response(JSON.stringify({ error: 'Verification code has expired. Please request a new one.' }), {
            status: 410,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        if (storedCode !== code) {
          return new Response(JSON.stringify({ error: 'Invalid verification code' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        // OTP is valid! Mark user as verified in Firestore
        const patchUserUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${uid}?updateMask.fieldPaths=isEmailVerified`;
        const patchUserBody = {
          fields: {
            isEmailVerified: { booleanValue: true }
          }
        };

        const patchUserRes = await fetch(patchUserUrl, {
          method: 'PATCH',
          headers: {
            'Authorization': `Bearer ${adminToken}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(patchUserBody)
        });

        if (!patchUserRes.ok) {
          return new Response(JSON.stringify({ error: `Failed to update user verification state: ${await patchUserRes.text()}` }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        // Delete verification document after successful validation to clean up
        await fetch(fetchUrl, {
          method: 'DELETE',
          headers: { 'Authorization': `Bearer ${adminToken}` }
        });

        return new Response(JSON.stringify({ success: true, message: 'Email verified successfully!' }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Route 2.1: Forgot Password - Send OTP
      if (url.pathname === '/v1/auth/forgot-password/send-otp') {
        if (request.method !== 'POST') {
          return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
            status: 405,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        let body;
        try {
          body = await request.json();
        } catch (_) {
          return new Response(JSON.stringify({ error: 'Malformed JSON body' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const { email } = body;
        if (!email || !email.includes('@')) {
          return new Response(JSON.stringify({ error: 'Please enter a valid email address' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const saJson = env.FIREBASE_SERVICE_ACCOUNT_JSON;
        if (!saJson) {
          return new Response(JSON.stringify({ error: 'Service account credentials missing on server' }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const adminToken = await getGoogleAccessToken(saJson);

        // 1. Lookup user in Firebase Auth by email
        const lookupUrl = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:lookup`;
        const lookupRes = await fetch(lookupUrl, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${adminToken}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ email: [email.trim()] })
        });

        if (!lookupRes.ok) {
          return new Response(JSON.stringify({ error: 'Failed to query authentication server' }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const lookupData = await lookupRes.json();
        if (!lookupData.users || lookupData.users.length === 0) {
          return new Response(JSON.stringify({ error: 'No account found with this email address' }), {
            status: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const uid = lookupData.users[0].localId;

        // Generate a 6-digit cryptographic OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = Math.floor(Date.now() / 1000) + 600; // 10 minutes from now

        // 2. Store OTP code to /users/{uid}/verification/forgot_password_otp in Firestore
        const patchUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${uid}/verification/forgot_password_otp?updateMask.fieldPaths=code&updateMask.fieldPaths=expiresAt`;
        const patchBody = {
          fields: {
            code: { stringValue: otp },
            expiresAt: { integerValue: expiresAt.toString() }
          }
        };

        const patchRes = await fetch(patchUrl, {
          method: 'PATCH',
          headers: {
            'Authorization': `Bearer ${adminToken}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(patchBody)
        });

        if (!patchRes.ok) {
          return new Response(JSON.stringify({ error: `Failed to store reset code: ${await patchRes.text()}` }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        // 3. Send Email via Resend API
        const resendKey = env.RESEND_API_KEY;
        if (!resendKey) {
          return new Response(JSON.stringify({ error: 'Email provider credentials missing on server' }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const emailRes = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${resendKey}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            from: 'ResumeOS <onboarding@resend.dev>',
            to: [email.trim()],
            subject: 'Reset Your ResumeOS Password',
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; borderRadius: 8px;">
                <h2 style="color: #8B6B58; text-align: center;">Reset Your Password</h2>
                <p>Hello,</p>
                <p>We received a request to reset your password for your ResumeOS account. Enter the 6-digit One-Time Password (OTP) below in the app to complete your password reset:</p>
                <div style="background-color: #f5f5f5; border-radius: 8px; padding: 15px; text-align: center; margin: 20px 0;">
                  <span style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #333;">${otp}</span>
                </div>
                <p style="color: #666; font-size: 12px; text-align: center;">This code will expire in 10 minutes. If you did not request a password reset, please ignore this email.</p>
              </div>
            `
          })
        });

        if (!emailRes.ok) {
          return new Response(JSON.stringify({ error: `Failed to dispatch email: ${await emailRes.text()}` }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        return new Response(JSON.stringify({ success: true, message: 'Password reset code sent to your email.' }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Route 2.2: Forgot Password - Verify OTP & Reset Password
      if (url.pathname === '/v1/auth/forgot-password/verify-and-reset') {
        if (request.method !== 'POST') {
          return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
            status: 405,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        let body;
        try {
          body = await request.json();
        } catch (_) {
          return new Response(JSON.stringify({ error: 'Malformed JSON body' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const { email, code, newPassword } = body;
        if (!email || !code || !newPassword) {
          return new Response(JSON.stringify({ error: 'Missing email, code, or newPassword' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        if (code.length !== 6) {
          return new Response(JSON.stringify({ error: 'Verification code must be exactly 6 digits' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        if (newPassword.length < 6) {
          return new Response(JSON.stringify({ error: 'New password must be at least 6 characters' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const saJson = env.FIREBASE_SERVICE_ACCOUNT_JSON;
        if (!saJson) {
          return new Response(JSON.stringify({ error: 'Service account credentials missing on server' }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const adminToken = await getGoogleAccessToken(saJson);

        // 1. Lookup user in Firebase Auth by email to get UID
        const lookupUrl = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:lookup`;
        const lookupRes = await fetch(lookupUrl, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${adminToken}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ email: [email.trim()] })
        });

        if (!lookupRes.ok) {
          return new Response(JSON.stringify({ error: 'Failed to query authentication server' }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const lookupData = await lookupRes.json();
        if (!lookupData.users || lookupData.users.length === 0) {
          return new Response(JSON.stringify({ error: 'No account found with this email address' }), {
            status: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const uid = lookupData.users[0].localId;

        // 2. Fetch OTP from Firestore
        const fetchUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${uid}/verification/forgot_password_otp`;
        const fetchRes = await fetch(fetchUrl, {
          headers: { 'Authorization': `Bearer ${adminToken}` }
        });

        if (!fetchRes.ok) {
          return new Response(JSON.stringify({ error: 'Verification code expired or not requested' }), {
            status: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const otpDoc = await fetchRes.json();
        const storedCode = otpDoc.fields?.code?.stringValue;
        const expiresAt = parseInt(otpDoc.fields?.expiresAt?.integerValue || '0', 10);
        const now = Math.floor(Date.now() / 1000);

        if (now > expiresAt) {
          return new Response(JSON.stringify({ error: 'Verification code has expired. Please request a new one.' }), {
            status: 410,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        if (storedCode !== code) {
          return new Response(JSON.stringify({ error: 'Invalid verification code' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        // 3. OTP is valid! Administratively update user's password in Firebase Auth
        const updateUrl = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:update`;
        const updateRes = await fetch(updateUrl, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${adminToken}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            localId: uid,
            password: newPassword
          })
        });

        if (!updateRes.ok) {
          return new Response(JSON.stringify({ error: `Failed to update password: ${await updateRes.text()}` }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        // 4. Delete the OTP document in Firestore to clean up
        await fetch(fetchUrl, {
          method: 'DELETE',
          headers: { 'Authorization': `Bearer ${adminToken}` }
        });

        return new Response(JSON.stringify({ success: true, message: 'Password updated successfully!' }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Route 2.5: Delete Account (Firestore Data & Firebase Auth User)
      if (url.pathname === '/v1/auth/delete-account') {
        if (request.method !== 'POST') {
          return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
            status: 405,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const authHeader = request.headers.get('Authorization') || '';
        if (!authHeader.startsWith('Bearer ')) {
          return new Response(JSON.stringify({ error: 'Missing or invalid Authorization header' }), {
            status: 401,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const token = authHeader.substring(7);
        let payload;
        try {
          payload = await verifyFirebaseToken(token, projectId);
        } catch (authError) {
          return new Response(JSON.stringify({ error: `Authentication failed: ${authError.message}` }), {
            status: 403,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const uid = payload.sub;

        const saJson = env.FIREBASE_SERVICE_ACCOUNT_JSON;
        if (!saJson) {
          return new Response(JSON.stringify({ error: 'Service account credentials missing on server' }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const adminToken = await getGoogleAccessToken(saJson);

        // 1. Delete all Firestore data
        await deleteUserFirestoreData(uid, adminToken, projectId);

        // 2. Delete Auth User account using Admin API
        const deleteAuthUrl = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:batchDelete`;
        const authDeleteRes = await fetch(deleteAuthUrl, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${adminToken}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ localIds: [uid], force: true })
        });

        if (!authDeleteRes.ok) {
          return new Response(JSON.stringify({ error: `Failed to delete authentication record: ${await authDeleteRes.text()}` }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        return new Response(JSON.stringify({ success: true, message: 'Account permanently deleted.' }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Route 3: Standard AI Generator Endpoint
      if (url.pathname === '/v1/ai/generate') {
        if (request.method !== 'POST') {
          return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
            status: 405,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const authHeader = request.headers.get('Authorization') || '';
        if (!authHeader.startsWith('Bearer ')) {
          return new Response(JSON.stringify({ error: 'Missing or invalid Authorization header' }), {
            status: 401,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const token = authHeader.substring(7);
        try {
          await verifyFirebaseToken(token, projectId);
        } catch (authError) {
          return new Response(JSON.stringify({ error: `Authentication failed: ${authError.message}` }), {
            status: 403,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        let body;
        try {
          body = await request.json();
        } catch (_) {
          return new Response(JSON.stringify({ error: 'Malformed JSON body' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const { action, data } = body;
        if (!action || !data) {
          return new Response(JSON.stringify({ error: 'Missing action or data in request body' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        let prompt;
        try {
          prompt = buildPrompt(action, data);
        } catch (promptError) {
          return new Response(JSON.stringify({ error: promptError.message }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const customGeminiKey = request.headers.get('x-custom-gemini-key') || '';
        const customOpenRouterKey = request.headers.get('x-custom-openrouter-key') || '';

        const result = await generateAI(prompt, customGeminiKey, customOpenRouterKey, env);

        return new Response(JSON.stringify(result), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Route 4: Get India IT jobs (Proxy to Adzuna)
      if (url.pathname === '/v1/jobs/india') {
        if (request.method !== 'GET') {
          return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
            status: 405,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const appId = env.ADZUNA_APP_ID;
        const appKey = env.ADZUNA_APP_KEY;

        if (!appId || !appKey) {
          return new Response(JSON.stringify({ error: 'Adzuna API credentials missing on server' }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const page = url.searchParams.get('page') || '1';
        const resultsPerPage = url.searchParams.get('results_per_page') || '50';

        const adzunaUrl = `https://api.adzuna.com/v1/api/jobs/in/search/${page}`
          + `?app_id=${appId}&app_key=${appKey}`
          + `&results_per_page=${resultsPerPage}&sort_by=date&category=it-jobs`
          + `&content-type=application/json`;

        try {
          const adzunaRes = await fetch(adzunaUrl);
          if (!adzunaRes.ok) {
            const errText = await adzunaRes.text();
            return new Response(JSON.stringify({ error: `Adzuna API error: ${errText}` }), {
              status: adzunaRes.status,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
          }

          const data = await adzunaRes.json();
          return new Response(JSON.stringify(data), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        } catch (fetchErr) {
          return new Response(JSON.stringify({ error: `Failed to fetch from Adzuna: ${fetchErr.message || fetchErr}` }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }
      }

      // 404 handler
      return new Response(JSON.stringify({ error: 'Not Found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });

    } catch (e) {
      console.error(`Internal server error: ${e.stack || e}`);
      return new Response(JSON.stringify({ error: e.message || e.toString() }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
  }
};
