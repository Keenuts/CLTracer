#pragma once

#include <CL/cl.hpp>

struct scene_t {
  int width;
  int height;
  int ker_width;
  int ker_height;

  cl_double3 camera_pos;
  cl_double3 camera_right;
  cl_double3 camera_up;
  cl_double3 camera_fwd;
};
