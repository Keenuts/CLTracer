#pragma once

#include <CL/cl.hpp>

struct scene_t {
  int width;
  int height;
  int ker_width;
  int ker_height;

  cl_float3 camera_pos;
  cl_float3 camera_right;
  cl_float3 camera_up;
  cl_float3 camera_fwd;
};
