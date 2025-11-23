// credit: Shuma Kise
// name of betta: Red Betta (Not goldfish)

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

///////////////////////////////////
// Modulo 289 without a division (only multiplications)
vec3 mod289(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}
vec2 mod289(vec2 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

// Modulo 7 without a division
vec3 mod7(vec3 x) {
  return x - floor(x * (1.0 / 7.0)) * 7.0;
}

// Permutation polynomial: (34x^2 + x) mod 289
vec3 permute(vec3 x) {
  return mod289((34.0 * x + 1.0) * x);
}

// Cellular noise, returning F1 and F2 in a vec2.
// Standard 3x3 search window for good F1 and F2 values
vec2 cellular(vec2 P) {
  const float K   = 0.142857142857; // 1/7
  const float Ko  = 0.428571428571; // 3/7
  const float jitter = 1.0;         // Less gives more regular pattern

  vec2 Pi = mod289(floor(P));
  vec2 Pf = fract(P);

  vec3 oi = vec3(-1.0, 0.0, 1.0);
  vec3 of = vec3(-0.5, 0.5, 1.5);

  vec3 px = permute(Pi.x + oi);
  vec3 p  = permute(px.x + Pi.y + oi); // p11, p12, p13

  vec3 ox = fract(p * K) - Ko;
  vec3 oy = mod7(floor(p * K))*K - Ko;

  vec3 dx = Pf.x + 0.5 + jitter * ox;
  vec3 dy = Pf.y - of + jitter * oy;
  vec3 d1 = dx * dx + dy * dy; // d11, d12 and d13, squared

  p = permute(px.y + Pi.y + oi); // p21, p22 and p23
  ox = fract(p * K) - Ko;
  oy = mod7(floor(p * K))*K - Ko;
  dx = Pf.x - 0.5 + jitter * ox;
  dy = Pf.y - of + jitter * oy;
  vec3 d2 = dx * dx + dy * dy; // d21, d22 and d23, squared

  p = permute(px.z + Pi.y + oi); // p31, p32 and p33
  ox = fract(p * K) - Ko;
  oy = mod7(floor(p * K))*K - Ko;
  dx = Pf.x - 1.5 + jitter * ox;
  dy = Pf.y - of + jitter * oy;
  vec3 d3 = dx * dx + dy * dy; // d31, d32 and d33, squared

  // Sort out the two smallest distances (F1, F2)
  vec3 d1a = min(d1, d2);
  d2 = max(d1, d2); // Swap to keep candidates for F2
  d2 = min(d2, d3); // neither F1 nor F2 are now in d3
  d1 = min(d1a, d2); // F1 is now in d1
  d2 = max(d1a, d2); // Swap to keep candidates for F2

  d1.xy = (d1.x < d1.y) ? d1.xy : d1.yx; // Swap if smaller
  d1.xz = (d1.x < d1.z) ? d1.xz : d1.zx; // F1 is in d1.x
  d1.yz = min(d1.yz, d2.yz);              // F2 is now not in d2.yz
  d1.y  = min(d1.y, d1.z);                // nor in d1.z
  d1.y  = min(d1.y, d2.x);                // F2 is in d1.y, we're done.

  return sqrt(d1.xy);
}

// Demo mapping
float colorMapping(vec2 xy) {
  return cellular(xy).x * 2.0 - 1.0;
}
///////////////////////////////////

float dot2(vec2 v) {
    return dot(v, v);
}

float swimPhase() {
    return u_time * 0.8;
}

float pectoralPhase(){
  return u_time * 0.5;
}

const float PEC_BASE_ANGLE_DEG = -75.0;

// convert degree to rad
float deg2rad(float d) {
    return d * 3.14159265 / 180.0;
}

float pectoralSwingOneSide() {
    float s = sin(pectoralPhase());
    return s;
}

// 1D Hash. 10 and 10000 aren't ideal, but oh well, good enough
float hash1(float n) {
    return fract(sin(n * 10.0) * 10000.0);
}

// basic sdBezier
float sdBezier(in vec2 pos, in vec2 A, in vec2 B, in vec2 C)
{
    vec2 a = B - A;
    vec2 b = A - 2.0 * B + C;
    vec2 c = a * 2.0;
    vec2 d = A - pos;

    float kk = 1.0 / dot(b, b + 1e-9); // anti-zero division
    float kx = kk * dot(a, b);
    float ky = kk * (2.0 * dot(a, a) + dot(d, b)) / 3.0;
    float kz = kk * dot(d, a);

    float res = 0.0;
    float p = ky - kx * kx;
    float p3 = p * p * p;
    float q = kx * (2.0 * kx * kx - 3.0 * ky) + kz;
    float h = q * q + 4.0 * p3;

    if (h >= 0.0)
    {
        h = sqrt(h);
        vec2 x = (vec2(h, -h) - q) / 2.0;
        vec2 uv = sign(x) * pow(abs(x), vec2(1.0 / 3.0));
        float t = clamp(uv.x + uv.y - kx, 0.0, 1.0);
        res = dot2(d + (c + b * t) * t);
    }
    else
    {
        float z = sqrt(-p);
        float v = acos(q / (p * z * 2.0)) / 3.0;
        float m = cos(v);
        float n = sin(v) * 1.732050808; // sqrt(3)
        vec3 t = clamp(vec3(m + m, -n - m, n - m) * z - kx, 0.0, 1.0);
        res = min(
            dot2(d + (c + b * t.x) * t.x),
            dot2(d + (c + b * t.y) * t.y)
        );
    }
    return sqrt(res);
}

// basic fin for that tail. Used for most stuff
float sdTailFin(
    vec2 p,
    vec2 A0, vec2 B0, vec2 C0,
    float freq,
    float ampB, float ampC,
    float phaseC,
    float phaseOffset,   // phase offset to change the phase of other fins
    float thickness
) {
    vec2 AB0 = B0 - A0;
    vec2 AC0 = C0 - A0;

    float rB = length(AB0);
    float rC = length(AC0);

    // initial angle at t=0
    float baseAngleB = atan(AB0.y, AB0.x);
    float baseAngleC = atan(AC0.y, AC0.x);
    float basePhase = swimPhase() * freq + phaseOffset;

    // angular change wrt time
    float angleB = baseAngleB + ampB * sin(basePhase);
    float angleC = baseAngleC + ampC * sin(basePhase + phaseC);

    // new location of the three coordinates of the bezier after transformation
    vec2 A = A0;
    vec2 B = A0 + rB * vec2(cos(angleB), sin(angleB));
    vec2 C = A0 + rC * vec2(cos(angleC), sin(angleC));

    float dCenter = sdBezier(p, A, B, C);
    return dCenter - thickness;
}


// simple circle
float sdCircle(vec2 p, vec2 c, float r) {
    return length(p - c) - r;
}

// definition of the spine 
vec2 spinePos(float t) {
    vec2 headPos = vec2(0.0, 0.7);
    vec2 tailPos = vec2(0.0, -0.2);
    vec2 spine = mix(headPos, tailPos, t);

    // bend the spine w.r.t. time
    float bend = -0.2 * sin(3.14159 * (t - 0.2) + swimPhase());
    spine.x += bend * 0.4;

    return spine;
}

// CENTRAL PART: This controls the shape of the fish
const int NUM_KEYS = 5;
const vec2 radiusKeys[NUM_KEYS] = vec2[NUM_KEYS](
    vec2(0.00, 0.10),  // Head 
    vec2(0.05, 0.12),  // Neck
    vec2(0.20, 0.14),  // Body
    vec2(0.80, 0.06),  // Tail
    vec2(1.00, 0.02)   // Tail tip
);

float catmullRom(float p0, float p1, float p2, float p3, float s) {
    float s2 = s * s;
    float s3 = s2 * s;
    return 0.5 * (
        2.0 * p1 +
        (-p0 + p2) * s +
        (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * s2 +
        (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * s3
    );
}

float radiusProfile(float t) {
    if (t <= radiusKeys[0].x) return radiusKeys[0].y;
    if (t >= radiusKeys[NUM_KEYS-1].x) return radiusKeys[NUM_KEYS-1].y;

    int seg = 0;
    for (int i = 0; i < NUM_KEYS - 1; ++i) {
        if (t >= radiusKeys[i].x && t <= radiusKeys[i+1].x) {
            seg = i;
            break;
        }
    }

    int i1 = seg;
    int i2 = seg + 1;
    int i0 = max(i1 - 1, 0);
    int i3 = min(i2 + 1, NUM_KEYS - 1);

    float t1 = radiusKeys[i1].x;
    float t2 = radiusKeys[i2].x;

    float s = (t - t1) / (t2 - t1);

    float p0 = radiusKeys[i0].y;
    float p1 = radiusKeys[i1].y;
    float p2 = radiusKeys[i2].y;
    float p3 = radiusKeys[i3].y;

    return catmullRom(p0, p1, p2, p3, s);
}

// Betta body
float sdBettaBody(vec2 p) {
    float d = 1e9;
    const int N = 30;

    for (int i = 0; i < N; ++i) {
        float t = float(i) / float(N - 1);

        vec2 spine = spinePos(t);
        float radius = radiusProfile(t);

        float dc = sdCircle(p, spine, radius);
        d = min(d, dc);
    }
    return d;
}

// MAX FINS COUNT!!! Lessen to relax the calculation load
const int MAX_FINS = 64;

// Ultimate fin function
//  tAttach               : where on the body the fin is attached from 0 to 1
//  numFins               : FIN COUNT!!! Be careful
//  lenScaleGlobal        : length of the fins
//  thicknessScaleGlobal  : thickness of the fins 
//  spreadScale           : spread of the fan
//  baseAngleOffset       : base angle offset 

float sdAllTailFins(
    vec2 p,
    float tAttach,
    int   numFins,
    float lenScaleGlobal,
    float thicknessScaleGlobal,
    float spreadScale,
    float baseAngleOffset,
    float phaseOffset
) {
    float t = clamp(tAttach, 0.0, 1.0);
    vec2 basePos = spinePos(t);

    float dt = 0.02;
    vec2 tangent = normalize(
        spinePos(min(t + dt, 1.0)) - spinePos(max(t - dt, 0.0)) + vec2(1e-5)
    );

    // baseangle with offset
    float baseAngle = atan(tangent.y, tangent.x) + baseAngleOffset;

    int N = clamp(numFins, 1, MAX_FINS);
    float spread = 1.0 * spreadScale;

    float d = 1e9;

    //Loop to add the fins using the fin function
    for (int i = 0; i < MAX_FINS; ++i) {
        if (i >= N) break;
        float fi = float(i);

        float denom = max(float(N - 1), 1.0);
        float u = (fi / denom) - 0.5;

        float angleOffset = u * spread;
        float angle = baseAngle + angleOffset;

        float lenScaleLocal = mix(0.8, 1.2, hash1(fi * 5.31));
        float lenBBase = 0.25 * lenScaleGlobal;
        float lenCBase = 0.65 * lenScaleGlobal;
        float lenB = lenBBase * lenScaleLocal;
        float lenC = lenCBase * lenScaleLocal;

        vec2 dirFin = vec2(cos(angle), sin(angle));

        vec2 A0 = basePos;
        vec2 B0 = basePos + lenB * dirFin;
        vec2 C0 = basePos + lenC * dirFin;

        float ampScale = 0.8 + 1.3 * abs(u);

        float freq   = 0.8;
        float ampB   = 0.10 * ampScale;
        float ampC   = 0.25 * ampScale;
        float phaseC = 0.0 + u * 0.5;

        float baseThickness = 0.008 * thicknessScaleGlobal;
        float thickScale = mix(0.1, 0.8, hash1(fi * 5.13));
        float thickness = baseThickness * thickScale;

        float dFin = sdTailFin(
            p,
            A0, B0, C0,
            freq, ampB, ampC, phaseC,
            phaseOffset,
            thickness
        );

        d = min(d, dFin);
    }

    return d;
}

//Base case for testing and debugging.
//Can be used with no parameters if lazy
float sdAllTailFins(vec2 p) {
    return sdAllTailFins(p, 0.9, 24, 1.0, 1.0, 1.0, 0.0, 0.0);
}

//Pectoral fin (chest fin) thingy
float sdPectoralFin(
    vec2 p,
    vec2 basePos,
    vec2 dirForward,
    float sideSign
) {
    // dirForward: head → tail
    vec2 f = normalize(dirForward);
    vec2 n = vec2(-f.y, f.x) * sideSign;  

    float a = deg2rad(PEC_BASE_ANGLE_DEG);

    vec2 dirBase = normalize(
        n * cos(a) + (-f) * sin(a)
    );

    // swing only to one side
    float swing = 0.8 * pectoralSwingOneSide();  // 0〜1くらい

    vec2 dirB = normalize(dirBase + 0.3 * swing * (-f));
    vec2 dirC = normalize(dirBase + 1.0 * swing * (-f));

    float lenB = 0.12;
    float lenC = 0.26;

    vec2 A = basePos;
    vec2 B = basePos + lenB * dirB;
    vec2 C = basePos + lenC * dirC;

    float thickness = 0.012;
    float dCenter = sdBezier(p, A, B, C);
    return dCenter - thickness;
}


float sdPectoralFinsSide(
    vec2 p,
    vec2 basePos,
    vec2 dirForward,
    float sideSign
) {
    vec2 f = normalize(dirForward);
    vec2 n = vec2(-f.y, f.x) * sideSign; 

    float a = deg2rad(PEC_BASE_ANGLE_DEG);
    vec2 baseDir = normalize(
        n * cos(a) + (-f) * sin(a)
    );

    float baseAngle = atan(baseDir.y, baseDir.x);

    const int NUM_PEC_FINS = 7;
    float spread = 0.1;

    float d = 1e9;

    for (int i = 0; i < NUM_PEC_FINS; ++i) {
        float fi = float(i);

        float u = (fi / float(NUM_PEC_FINS - 1)) - 0.5;

        float angleOffset = u * spread;
        float angle = baseAngle + angleOffset;

        vec2 dirBaseFin = vec2(cos(angle), sin(angle));

        float swing = 0.7 * pectoralSwingOneSide();

        vec2 dirB = normalize(dirBaseFin + 0.3 * swing * (-f));
        vec2 dirC = normalize(dirBaseFin + 1.0 * swing * (-f));

        float lenScale = mix(0.9, 1.1, hash1(fi * 7.31 + (sideSign > 0.0 ? 1.0 : 2.0)));

        float lenBBase = 0.10;
        float lenCBase = 0.26;
        float lenB = lenBBase * lenScale;
        float lenC = lenCBase * lenScale;

        vec2 A = basePos;
        vec2 B = basePos + lenB * dirB;
        vec2 C = basePos + lenC * dirC;

        float baseThickness = 0.010;
        float thickScale = mix(0.2, 0.5,
                               hash1(fi * 3.17 + (sideSign > 0.0 ? 5.0 : 6.0)));
        float thickness = baseThickness * thickScale;

        float dFin = sdBezier(p, A, B, C) - thickness;
        d = min(d, dFin);
    }
    return d;
}

float sdAllPectoralFins(vec2 p) {
    float tBase = 0.35;
    vec2 spineC = spinePos(tBase);

    vec2 f = normalize(spinePos(tBase + 0.02) - spinePos(tBase - 0.02) + vec2(1e-5));
    vec2 n = vec2(-f.y, f.x); 

    float r = radiusProfile(tBase);
    
    //base position for the left and the right
    vec2 baseL = spineC + n * r;
    vec2 baseR = spineC - n * r;

    float dL = sdPectoralFinsSide(p, baseL, f, +1.0);
    float dR = sdPectoralFinsSide(p, baseR, f, -1.0);

    return min(dL, dR);
}

float sdFinsAlongSpineRange(
    vec2 p,
    float tStart,
    float tEnd,
    int numFins, //This is the total number of fins along the spine
    float lenScaleGlobal,
    float thicknessScaleGlobal,
    float baseAngleOffset,
    float phaseOffset //can be used to offset the angle of fins, but usually keep it at 0
) {
    float d = 1e9;
    int N = clamp(numFins, 1, MAX_FINS);

    //fail safe
    float t0 = min(tStart, tEnd);
    float t1 = max(tStart, tEnd);

    for (int i = 0; i < MAX_FINS; ++i) {
        if (i >= N) break;

        float fi = float(i);
        float denom = max(float(N - 1), 1.0);
        float u = (N == 1) ? 0.0 : (fi / denom);  

        float t = mix(t0, t1, u);
        t = clamp(t, 0.0, 1.0);

        vec2 basePos = spinePos(t);

        float dt = 0.02;
        vec2 tangent = normalize(
            spinePos(min(t + dt, 1.0)) - spinePos(max(t - dt, 0.0)) + vec2(1e-5)
        );

        float baseAngle = atan(tangent.y, tangent.x) + baseAngleOffset;

        // spread the angles slightly
        float jitter = (hash1(fi * 3.73) - 0.5) * 0.4; 
        float angle = baseAngle + jitter;

        // length, with slight randomness with hash 1. In between 0.9 to 1.1 times
        float lenScaleLocal = mix(0.9, 1.1, hash1(fi * 5.31));
        float lenBBase = 0.25 * lenScaleGlobal;
        float lenCBase = 0.65 * lenScaleGlobal;
        float lenB = lenBBase * lenScaleLocal;
        float lenC = lenCBase * lenScaleLocal;

        vec2 dirFin = vec2(cos(angle), sin(angle));

        vec2 A0 = basePos;
        vec2 B0 = basePos + lenB * dirFin;
        vec2 C0 = basePos + lenC * dirFin;

        // adjust as needed, for the animation
        float ampScale = 2.0;
        float freq   = 0.8;
        float ampB   = 0.10 * ampScale;
        float ampC   = 0.25 * ampScale;
        float phaseC = 0.0 + u * 1.2;

        float baseThickness = 0.008 * thicknessScaleGlobal;
        float thickScale = mix(0.3, 0.9, hash1(fi * 5.13));
        float thickness = baseThickness * thickScale;

        float dFin = sdTailFin(
            p,
            A0, B0, C0,
            freq, ampB, ampC, phaseC,
            phaseOffset,
            thickness
        );

        d = min(d, dFin);
    }

    return d;
}

//Throw in the calculated sd stuff in here, to mix the colors. 
vec3 mixColor(vec3 baseColor, float dShape, vec3 shapeColor, float alpha) {
    float mask  = smoothstep(0.02, 0.0, dShape);
    float blend = mask * alpha;
    return mix(baseColor, shapeColor, blend);
}

// -------------------- main --------------------
void main() {
    vec2 p = (2.0 * gl_FragCoord.xy - u_resolution.xy) / u_resolution.y;

    // All the sdf calculations
    float dBody = sdBettaBody(p);
    float dTail = sdAllTailFins(p, 0.9, 32, 1.0, 1.0, 0.7, 0.0, 0.0);
    float dPec  = sdAllPectoralFins(p);
    float dTailThin = sdAllTailFins(p, 0.9, 8, 0.9, 0.4, 0.6, 0.0, 0.0);
    float dTailSpread = sdAllTailFins(p, 0.9, 30, 0.8, 0.4, 0.6, 0.3, 1.4);
    float dBack = sdAllTailFins(p, 0.2, 24, 1.0, 0.4, 0.4, 0.0, 0.0);
    float dBack2 = sdAllTailFins(p, 0.5, 32, 1.0, 0.4, 0.7, 0.2, 0.0);

    float dSpine = sdFinsAlongSpineRange(p, 0.2, 0.8, 60, 0.7, 0.4, 0.0, 0.3);
    float dSpine2 = sdFinsAlongSpineRange(p, 0.2, 0.8, 60, 0.5, 0.4, 0.0, 0.1);

    // color for each body segements
    vec3 bg      = vec3(0.6, 0.7, 1.0);
    vec3 bodyCol = vec3(0.9, 0.25, 0.3);
    vec3 pecCol  = vec3(0.9, 0.25, 0.3);
    vec3 tailCol = vec3(0.9, 0.3, 0.3);
    vec3 tailColThin = vec3(0.7, 0.3, 0.3);
    vec3 backCol = vec3(0.9, 0.3, 0.3);
    vec3 spineCol2 = vec3(0.85, 0.3, 0.3);

    vec3 bodyColBase = vec3(0.9, 0.25, 0.3); //For the base body color
    vec3 bodyColEdge = vec3(0.8, 0.2, 0.2); // body color for outer rim

    float rimWidth = 0.06;
    float rimFactor = smoothstep(-rimWidth, 0.0, dBody);

    bodyCol = mix(bodyColBase, bodyColEdge, rimFactor);

    vec3 color = bg;
    //MIX EVERYTHING
    color = mixColor(color, dBody, bodyCol, 0.9);
    color = mixColor(color, dBack, backCol, 0.4);
    color = mixColor(color, dBack2, backCol, 0.55);
    color = mixColor(color, dPec, pecCol, 0.6);
    color = mixColor(color, dTail, tailCol, 0.6);
    color = mixColor(color, dTailThin, tailColThin, 0.7);
    color = mixColor(color, dSpine, tailCol, 0.6);
    color = mixColor(color, dSpine2, spineCol2, 0.8);
    color = mixColor(color, dTailSpread, tailCol, 0.6);

    ///////////////////
    //noise from https://www.redblobgames.com/x/2107-webgl-noise/webgl-noise/webdemo/cellular.html
    //NOISE!!!! The worley noise 2D defined here
    float t = u_time;

    // First noise layer
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;
    vec2 uv1 = uv * u_resolution.xy / min(u_resolution.x, u_resolution.y);
    float n1 = colorMapping(uv1 * 4.0 + vec2(t * 0.3, t * 0.1)); 
    float v1 = 0.5 + 0.5 * n1;
    vec3 col1 = vec3(v1);
    float alpha1 = v1 * 0.3; 

    color = mix(color, col1, alpha1);

    // Second noise layer
    vec2 uv2 = uv * u_resolution.xy / min(u_resolution.x, u_resolution.y);

    float n2 = colorMapping(uv2 * 12.0 + vec2(u_time * 0.4, u_time * 0.7));
    float v2 = 0.5 + 0.5 * n2;
    vec3 col2 = vec3(v2);

    float alpha2 = v2 * 0.3;
    color = mix(color, col2, alpha2);

    colour_out = vec4(color, 1.0);
}