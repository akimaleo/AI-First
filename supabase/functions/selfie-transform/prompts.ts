// Prompt templates for AI Capture the Moment.
// Each key maps to a game scenario surfaced by the Flutter client.
// Keep prompts identity-preserving: they describe *modifications* to the
// captured selfie rather than regenerating the subject from scratch.

export type PromptKey =
  | 'third_eye'
  | 'zombie'
  | 'robot'
  | 'alien_skin'
  | 'vampire'
  | 'cartoon'
  | 'werewolf'
  | 'cyberpunk'
  | 'angel'
  | 'devil';

export interface PromptTemplate {
  key: PromptKey;
  label: string;
  prompt: string;
  negativePrompt?: string;
  guidance: number;
}

const DEFAULT_NEGATIVE =
  'deformed, distorted face, disfigured, low quality, blurry, watermark, text';

export const PROMPT_TEMPLATES: Record<PromptKey, PromptTemplate> = {
  third_eye: {
    key: 'third_eye',
    label: 'Third Eye',
    prompt:
      'add a realistic third eye on the forehead of the person, keep the ' +
      'original face, hair, and background unchanged, seamless blending, ' +
      'photorealistic',
    negativePrompt: DEFAULT_NEGATIVE,
    guidance: 7.5,
  },
  zombie: {
    key: 'zombie',
    label: 'Zombie',
    prompt:
      'transform the person into a zombie with pale green decayed skin, ' +
      'glowing yellow eyes, and subtle scars, keep the same face shape and ' +
      'pose, cinematic horror lighting',
    negativePrompt: DEFAULT_NEGATIVE,
    guidance: 7.0,
  },
  robot: {
    key: 'robot',
    label: 'Robot',
    prompt:
      'turn the person into a sleek humanoid robot with chrome metal plating ' +
      'on the face, glowing blue LED accents, keep the same facial structure ' +
      'and expression',
    negativePrompt: DEFAULT_NEGATIVE,
    guidance: 7.5,
  },
  alien_skin: {
    key: 'alien_skin',
    label: 'Alien',
    prompt:
      'give the person iridescent green alien skin with subtle scales, large ' +
      'black alien eyes, keep the same face shape, hairstyle, and background',
    negativePrompt: DEFAULT_NEGATIVE,
    guidance: 7.0,
  },
  vampire: {
    key: 'vampire',
    label: 'Vampire',
    prompt:
      'give the person pale vampire skin, red glowing eyes, long visible ' +
      'fangs, a gothic dark aesthetic, keep the original face and background',
    negativePrompt: DEFAULT_NEGATIVE,
    guidance: 7.0,
  },
  cartoon: {
    key: 'cartoon',
    label: 'Cartoon',
    prompt:
      'convert the photo into a high-quality 3d pixar style cartoon of the ' +
      'same person, exaggerated eyes, smooth skin shading, preserve the pose',
    guidance: 8.0,
  },
  werewolf: {
    key: 'werewolf',
    label: 'Werewolf',
    prompt:
      'transform the person into a werewolf with brown fur on the face, ' +
      'wolf snout and ears, yellow eyes, sharp fangs, keep the same head pose',
    negativePrompt: DEFAULT_NEGATIVE,
    guidance: 7.5,
  },
  cyberpunk: {
    key: 'cyberpunk',
    label: 'Cyberpunk',
    prompt:
      'add neon cyberpunk cybernetic implants to the face, glowing circuit ' +
      'tattoos, holographic visor over one eye, neon pink and blue lighting',
    negativePrompt: DEFAULT_NEGATIVE,
    guidance: 7.5,
  },
  angel: {
    key: 'angel',
    label: 'Angel',
    prompt:
      'add a golden halo above the head and soft white feathered wings behind ' +
      'the person, warm heavenly glow on the face, keep the original face',
    negativePrompt: DEFAULT_NEGATIVE,
    guidance: 7.0,
  },
  devil: {
    key: 'devil',
    label: 'Devil',
    prompt:
      'add small red curved horns on the forehead, a slight red tint to the ' +
      'skin, glowing red eyes, subtle smoke behind the head, keep the face',
    negativePrompt: DEFAULT_NEGATIVE,
    guidance: 7.0,
  },
};

export function isPromptKey(value: string): value is PromptKey {
  return value in PROMPT_TEMPLATES;
}

export function getPrompt(key: string): PromptTemplate {
  if (!isPromptKey(key)) {
    throw new Error(`Unknown prompt key: ${key}`);
  }
  return PROMPT_TEMPLATES[key];
}

export const PROMPT_KEYS = Object.keys(PROMPT_TEMPLATES) as PromptKey[];
