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
    return `Analyze the following job description and extract structured information.
Return ONLY valid JSON matching this exact schema:
{
  "role": "string (job title)",
  "experienceLevel": "junior|mid|senior",
  "requiredSkills": ["skill1", "skill2"],
  "preferredSkills": ["skill1"],
  "keywords": ["keyword1", "keyword2"],
  "domainKeywords": ["domain1"]
}

Rules:
- keywords should be technical terms, tools, frameworks found in the JD
- domainKeywords should be business/domain terms (e.g., "fintech", "e-commerce")  
- Do NOT add skills not mentioned in the JD
- requiredSkills = explicitly required, preferredSkills = nice-to-have

Job Description:
${jobDescription}`;
  }

  if (action === 'rewriteProjectBullets') {
    const { projectTitle, projectDescription, technologies = [], targetRole, keywords = [], linkedSkills = [] } = data;
    if (!projectTitle || !projectDescription || !targetRole) {
      throw new Error('Missing required fields for rewriteProjectBullets');
    }
    const skillsPrompt = linkedSkills.length > 0
        ? `Linked skills to naturally incorporate and highlight: ${linkedSkills.join(', ')}\n`
        : '';
    return `Rewrite the following project description as 3-4 ATS-optimized resume bullet points.

Target role: ${targetRole}
Project: ${projectTitle}
Description: ${projectDescription}
Technologies: ${technologies.join(', ')}
${skillsPrompt}
Keywords to incorporate naturally: ${keywords.slice(0, 8).join(', ')}

Rules:
- Start each bullet with a strong action verb (Built, Developed, Engineered, Designed, Optimized, etc.)
- Be specific with numbers/metrics where possible (use realistic estimates if not provided)
- Keep each bullet to 1-2 lines maximum
- Sound human and professional, not robotic
- Never invent technologies or experiences not present in the description
- ATS-friendly: no symbols, special characters, or graphics
- Select the 3-4 most relevant linked skills (from the linked list above, if any) or project technologies for a ${targetRole} role.

Return ONLY valid JSON:
{
  "bullets": ["bullet 1", "bullet 2", "bullet 3"],
  "selectedSkills": ["skill 1", "skill 2", "skill 3"]
}`;
  }

  if (action === 'generateProfessionalSummary') {
    const { candidateBackground, targetRole, keywords = [], topSkills = [] } = data;
    if (!candidateBackground || !targetRole) {
      throw new Error('Missing required fields for generateProfessionalSummary');
    }
    return `Write a 2-3 sentence professional summary for a resume.

Target role: ${targetRole}
Candidate background: ${candidateBackground}
Key skills: ${topSkills.slice(0, 6).join(', ')}
Keywords to incorporate: ${keywords.slice(0, 6).join(', ')}

Rules:
- Write in third person (no "I" or "me")
- Sound confident but not arrogant
- Be specific and technical where appropriate
- ATS-optimized: include role title and 2-3 key skills naturally
- No clichés ("passionate", "team player", "go-getter")
- 40-60 words maximum

Return ONLY valid JSON:
{
  "summary": "Your generated summary here."
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

Strict Rules for Generation:
1. **Length Constraints**: The generated summary MUST be strictly between 100 and 150 words. Do not make it shorter than 100 words or longer than 150 words.
2. **Authenticity & Tone**: Keep the professional summary authentic and human-sounding. Do NOT make it sound like a typical corporate AI brochure or generic marketing fluff.
3. **Forbid Clichés**: Avoid buzzword clichés like "seasoned," "dynamic," "visionary," "passionate," "detail-oriented," "results-driven," "highly motivated," "thought leader," or "expert."
4. **Strip Filler Adjectives**: Strip out generic filler adjectives in favor of varied, natural sentence structures.
5. **Rely on Hard Facts & Metrics**: Instead of inventing melodramatic fluff or generic job titles, rely strictly on hard facts, specific metrics, measurable achievements, and actual work philosophy from the provided user data (experience, education, and projects). Do not exaggerate or fabricate numbers or experiences.
6. **Varied, Natural Sentence Structure**: Use clean, straightforward, varied sentence structures. Avoid repetitive paragraph patterns.
7. **Implicit First-Person/Active Voice**: Write in the active professional voice (e.g., starting with the role name, like "Software engineer building..." or "Backend developer focusing on..."). Do not use third-person biography pronouns ("he", "she", "they").
8. **The "Read Out Loud" / Coffee Test**: Always apply the "read out loud" test to self-correct the draft. If the candidate would feel pretentious saying the summary directly to a recruiter over a cup of coffee, simplify the language until it sounds like a straightforward, confident professional describing their actual value.

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
        'HTTP-Referer': 'https://aicareer.os',
        'X-Title': 'AI Career OS',
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
            from: 'SmartResume <onboarding@resend.dev>',
            to: [email],
            subject: 'Verify Your SmartResume Account',
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; borderRadius: 8px;">
                <h2 style="color: #673AB7; text-align: center;">Verify Your SmartResume Account</h2>
                <p>Hello,</p>
                <p>Thank you for signing up for SmartResume! To complete your registration and proceed to the onboarding checklist, please enter the 6-digit One-Time Password (OTP) below within the next 10 minutes:</p>
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
