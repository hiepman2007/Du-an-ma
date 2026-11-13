// JSON schema (strict) cho Structured Outputs. Moi truong deu bat buoc; dung null / mang rong cho truong khong ap dung.
const str = { type: 'string' };
const nstr = { type: ['string', 'null'] };
const nint = { type: ['integer', 'null'] };
const nbool = { type: ['boolean', 'null'] };
const num = { type: 'number' };
const nnum = { type: ['number', 'null'] };
const strArr = { type: 'array', items: str };

function obj(properties) {
  return { type: 'object', properties, required: Object.keys(properties), additionalProperties: false };
}
const nullable = (schema) => ({ anyOf: [schema, { type: 'null' }] });

// Tang 1: bo may chuyen biet; tang 2: dung chung moi mon; tang 3: custom_sim (du phong).
export const SPECIALIZED_TYPES = ['formula_lab', 'function_graph', 'reaction_lab', 'chem_formula', 'motion_sim'];
export const GENERIC_TYPES = [
  'text_section', 'mcq', 'true_false', 'fill_blank', 'matching', 'ordering', 'flashcards',
  'step_solver', 'concept_map', 'image_card', 'code_demo',
];
export const BLOCK_TYPES = [...GENERIC_TYPES, ...SPECIALIZED_TYPES, 'custom_sim'];
export const INTERACTIVE_TYPES = [
  'formula_lab', 'function_graph', 'reaction_lab', 'chem_formula', 'motion_sim',
  'matching', 'ordering', 'step_solver', 'concept_map', 'custom_sim',
];
export const MOTION_KINDS = ['projectile', 'free_fall', 'pendulum'];
export const GRAPH_TOOLS = ['tangent', 'area', 'roots', 'extrema'];

const variable = obj({ name: str, label: str, unit: str, min: num, max: num, step: num, default: num });

const reagent = obj({
  id: str,
  name: str,
  formula: str,
  color: str, // ma mau hex, vi du "#d0e8ff"
  state: { type: 'string', enum: ['solid', 'liquid', 'solution', 'gas'] },
});
const reaction = obj({
  reagents: strArr, // cac id chat tham gia
  equation: str,
  observation: str,
  color: str, // mau dung dich sau phan ung (hex)
  gas: { type: 'boolean' },
  precipitate: { type: 'boolean' },
  precipitate_color: nstr,
  heat: { type: 'string', enum: ['exo', 'endo', 'none'] },
  min_temp: nnum, // nhiet do toi thieu (do C) de phan ung xay ra, null neu khong can
  explanation: str,
});

const blockSchema = obj({
  type: { type: 'string', enum: BLOCK_TYPES },
  topic: str,
  title: nstr,
  // text_section: markdown; mcq/true_false/fill_blank/step_solver: de bai; cac loai khac: huong dan ngan
  body: nstr,
  options: { type: 'array', items: str },             // mcq
  answer_index: nint,                                 // mcq: chi so dap an dung (tu 0)
  answer_bool: nbool,                                 // true_false
  answers: { type: 'array', items: str },             // fill_blank
  pairs: { type: 'array', items: obj({ left: str, right: str }) },  // matching
  items: { type: 'array', items: str },               // ordering: THU TU DUNG
  cards: { type: 'array', items: obj({ front: str, back: str }) },  // flashcards
  steps: { type: 'array', items: obj({ text: str, answer: nstr }) }, // step_solver
  nodes: { type: 'array', items: obj({ id: str, label: str, detail: str }) },        // concept_map
  edges: { type: 'array', items: obj({ from: str, to: str, label: str }) },          // concept_map
  lab: nullable(obj({ formula: str, result_label: str, result_unit: str, variables: { type: 'array', items: variable } })),
  graph: nullable(obj({
    expression: str,
    extra_expressions: strArr, // ham phu de so sanh
    x_min: num,
    x_max: num,
    params: { type: 'array', items: variable },
    tools: { type: 'array', items: { type: 'string', enum: GRAPH_TOOLS } },
  })),
  reaction: nullable(obj({
    setup: str,
    reagents: { type: 'array', items: reagent },
    reactions: { type: 'array', items: reaction },
    no_reaction_text: str,
    safety: nstr,
  })),
  chem: nullable(obj({ formula: str, name: str })),
  motion: nullable(obj({ kind: { type: 'string', enum: MOTION_KINDS }, variables: { type: 'array', items: variable } })),
  image_query: nstr, // image_card: tu khoa tieng Anh de tim anh tren Wikimedia Commons
  sim_prompt: nstr,  // custom_sim: mo ta mo phong can tao (app sinh khi hoc sinh bam)
  code: nullable(obj({ language: str, source: str, output: str })), // code_demo: code minh hoa + ket qua chay (AI ghi)
  explanation: nstr,
  source_quote: nstr,
  source_page: nint,
  source_url: nstr,
});

export const lessonSchema = obj({
  title: str,
  blocks: { type: 'array', items: blockSchema },
});

export const blocksOnlySchema = obj({
  blocks: { type: 'array', items: blockSchema },
});

export const outlineSchema = obj({
  title: str,
  language: str,
  subject: str, // mon hoc, vi du "Hoa hoc", "Toan", "Lich su"
  lessons: {
    type: 'array',
    items: obj({ id: str, title: str, objectives: strArr, minutes: { type: 'integer' }, interaction_hint: str }),
  },
});

export const sourcesSchema = obj({
  sources: {
    type: 'array',
    items: obj({ title: str, url: str, snippet: str }),
  },
});

export const explainSchema = obj({
  hint: str,
  explanation: str,
  root_cause: str,
  weak_topic: str,
});

export const simulationSchema = obj({
  title: str,
  instructions: str, // huong dan hoc sinh tuong tac
  html: str,         // mot file HTML tu chua (CSS/JS noi tuyen), khong tai tai nguyen ngoai
});
