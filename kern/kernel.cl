#define GEN_SWAP(Type)        \
static inline                 \
void swap(Type *a, Type *b) { \
  Type c = *a;                \
  *a = *b;                    \
  *b = c;                     \
}
GEN_SWAP(float);

typedef struct {
  int width;
  int height;
  int ker_width;
  int ker_height;

  float3 camera_pos;
  float3 camera_right;
  float3 camera_up;
  float3 camera_fwd;
} scene_t;

__constant sampler_t sampler = CLK_NORMALIZED_COORDS_FALSE
                             | CLK_ADDRESS_CLAMP_TO_EDGE
                             | CLK_FILTER_NEAREST;

static
bool intersect(
  float3 origin,
  float3 dir,
  float3 center,
  float r,
  float3 *pt)
{
  float3 oc;
  float d2, ch2, oh, t1, t2;
  int collide = 1;

  oc = (center - origin);
  oh = dot(oc, dir);
  collide = mix((float)collide, 0.0f, (float)(oh < 0.f));

  ch2 = pow(length(oc), 2.0f) - (oh * oh);
  collide = (int)mix((float)collide, 0.0f, (float)(ch2 > r * r));

  d2 = sqrt(r * r - ch2);
  t1 = oh + d2;
  t2 = oh - d2;
  if (t1 > t2)
    swap(&t1, &t2);
  t1 = mix(t1, t2, (float)(t1 < 0));
  collide = (int)mix((float)collide, 0.0f, (float)(t1 < 0.));

  *pt = origin + dir * t1;
  return collide;
}

#define FOV 45.0f
#define PI 3.14159265358979323846f
#define DEG2RAD 0.017453292519943295f

typedef struct {
    float3 diffuse;
    float3 specular;

    float shininess;
    float specular_level;
    float opacity;
} mtl_t;

typedef struct {
    mtl_t mtl;
    float3 o;
    float r;
} obj_t;

float3 refl(float3 i, float3 n)
{
    i = normalize(i);
    n = normalize(n);
    return normalize(i - (n * 2.f * dot(n, i)));
}

float4 additive(float4 a, float4 b)
{
    a.x = mix(a.x, b.x, b.w);
    a.y = mix(a.y, b.y, b.w);
    a.z = mix(a.z, b.z, b.w);
    a.w = max(a.w, b.w);
    return a;
}

static float3
compute_ray(
    __constant scene_t *scene,
    int2 pos
)
{
    float width, height, t_width, t_height;
    float3 center, pt;

    width = scene->width;
    height = scene->height;

    float L = width / tan(DEG2RAD * (FOV * 0.5f)) * 2.0f;

    center = scene->camera_pos + scene->camera_fwd * L;

    t_width = mix(-width, width, pos.x / width) * 0.5f;
    t_height= mix(-height, height, (pos.y / height)) * 0.5f;

    pt = scene->camera_right * t_width
        + scene->camera_up * t_height
        + scene->camera_fwd
        + center;
    return normalize(pt - scene->camera_pos);
}

static float4
shade_object(
    float3 view,
    float3 pt,
    float3 norm,
    const mtl_t *mtl)
{
    const float3 sun_dir = normalize((float3)(0.4f, -0.8f, -0.9f));

    float l = clamp(dot(norm, sun_dir), 0.f, 1.f);
    l = max(0.2f, l);
    float3 diff = mtl->diffuse * l;

    float s = clamp(dot(refl(sun_dir, norm), view), 0.f, 1.f);
    float3 spec = mtl->specular * pow(s, mtl->shininess);
    spec *= mtl->specular_level;

    float3 color = diff + spec;
    color = diff;

    float4 out;
    out.xyz = color;
    out.w = mtl->opacity;
    return out;
}

static float4
render_obj(
    __constant scene_t *p,
    int2 screen_pos,
    const obj_t *obj)
{
    float3 pt;
    float3 view = compute_ray(p, screen_pos);

    int touch = intersect(p->camera_pos, view, obj->o, obj->r, &pt);
    float3 normal = normalize(pt - obj->o);

    float4 out = shade_object(view, pt, normal, &obj->mtl);
    out.w = mix(0.f, out.w, (float)touch);

    return out;
}

__kernel void raytracer(
  __constant scene_t *p,
  __write_only image2d_t output
)
{
    const mtl_t mtl_a = {
        .diffuse = (float3)(155, 255, 0),
        .specular = (float3)(255, 255, 255),
        .shininess = 90.f,
        .specular_level = 2.5f,
        .opacity = 1.f,
    };

    const mtl_t mtl_b = {
        .diffuse = (float3)(255, 0, 0),
        .specular = (float3)(255, 255, 255),
        .shininess = 0.2f,
        .specular_level = 0.1f,
        .opacity = 1.,
    };

    const obj_t obj_a = {
        .mtl = mtl_a,
        .o = (float3)(0.0f, 0.0f, 0.0f),
        .r = 2.f,
    };

    const obj_t obj_b = {
        .mtl = mtl_b,
        .o = (float3)(1.0f, 1.0f, 5.0f),
        .r = 1.f,
    };

    const float3 sky_color = (float3)(240, 248, 255);

    const int2 pos = (int2)(
            get_global_id(0) * p->ker_width, get_global_id(1) * p->ker_height);

    for (int y = 0; y < p->ker_height; y++) {
        for (int x = 0; x < p->ker_width; x++) {
            bool touch;
            float3 look_d, normal, pt;
            float3 color;

            int2 local_pos = (int2)(pos.x + x, pos.y + y);

            float4 out = (float4)(sky_color, 1.f);

            float4 c;

            c = render_obj(p, local_pos, &obj_b);
            out = additive(out, c);

            c = render_obj(p, local_pos, &obj_a);
            out = additive(out, c);


            uint4 albedo = (uint4)(out.x, out.y, out.z, 255);
            write_imageui(output, local_pos, albedo);
        }
    }
}
