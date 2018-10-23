#include <CL/cl.hpp>
#include <cassert>
#include <fstream>
#include <iostream>
#include <vector>

#include "app.h"
#include "types.h"
#include "lodepng.h"
#include "timer.h"

app_t::app_t() {

  cl_int res = CL_SUCCESS;
  std::vector<cl::Platform> platforms;
  std::vector<cl::Device> devices;

  res = cl::Platform::get(&platforms);
  assert(res == CL_SUCCESS && platforms.size() != 0);

  for (cl::Platform p : platforms) {
    res = p.getDevices(CL_DEVICE_TYPE_ALL, &devices);
    if (res == CL_SUCCESS) {
      assert(devices.size() > 0 && "[Platform] No compatible devices found");
      m_device = devices[0];
      m_platform = p;
      break;
    }
    else if (res == CL_DEVICE_NOT_FOUND)
      std::cout << "[Platform] Device type not found\n";
    else
      std::cout << "[Platform] Unspecified error\n";
  }
  assert(res == CL_SUCCESS);

  m_context = cl::Context({ m_device });
}

int app_t::add_kernel(const char* filename) {
  cl_int res;
  std::ifstream f(filename);
  std::string content((std::istreambuf_iterator<char>(f)),
                       std::istreambuf_iterator<char>());
  f.close();

  cl::Program k(m_context, content);
  res = k.build({ m_device });
  if (res != CL_SUCCESS) {
    std::cout << "[Kernel] Unable to build the kernel : " << filename << ":\n";
    std::cout << k.getBuildInfo<CL_PROGRAM_BUILD_LOG>(m_device) << "\n";
    return 1;
  }

  m_kernels.push_back(k);
  std::cout << "[Kernel] Kernel " << filename << " successfuly loaded.\n";
  return 0;
}

void app_t::render() {
  struct scene_t p =
  {
    256,
    256,
    8,
    8,
    { 0.0f , 0.0f, -20.0f, 0.0f },
    { 1.0f , 0.0f, 0.0f  , 0.0f },
    { 0.0f , 1.0f, 0.0f  , 0.0f },
    { 0.0f , 0.0f, 1.0f  , 0.0f },
  };

  const int ker_nbr_w = p.width / p.ker_width;
  const int ker_nbr_h = p.height / p.ker_height;

  cl_mem_flags flags = CL_MEM_WRITE_ONLY | CL_MEM_HOST_READ_ONLY;
  cl::ImageFormat format(CL_RGBA, CL_UNSIGNED_INT8);
  cl_int res;

  cl::Image2D image(m_context, flags, format, p.width, p.height, 0, NULL, &res);
  assert(res == CL_SUCCESS);

  cl::Buffer buffer(m_context, CL_MEM_READ_ONLY, sizeof(p));

  cl::CommandQueue queue(m_context, m_device);
  queue.enqueueWriteBuffer(buffer, CL_TRUE, 0, sizeof(p), &p);

  cl::Kernel k = cl::Kernel(m_kernels[0],"raytracer");
  k.setArg(0, buffer);
  k.setArg(1, image);

  double elapsed;
  {
    scoped_timer t(elapsed);
    queue.enqueueNDRangeKernel(
      k,
      cl::NullRange,
      cl::NDRange(ker_nbr_w, ker_nbr_h),
      cl::NullRange
    );

    printf("[INFO] Rendering using %u kernels\n", ker_nbr_w * ker_nbr_h);
    queue.finish();
  }
  printf("[INFO] Rendering done in %d ms.\n", (int)(elapsed * 1000.));

#ifdef OUTPUT
  uint8_t *render = new uint8_t[4 * p.width * p.height];

  cl::size_t<3> origin;
  origin[0] = 0; origin[1] = 0; origin[2] = 0;
  cl::size_t<3> region;
  region[0] = p.width; region[1] = p.height; region[2] = 1;

  queue.enqueueReadImage(
    image,
    CL_TRUE,
    origin,
    region,
    0,
    0,
    render,
    nullptr,
    nullptr);

  lodepng::encode("output.png", render, p.width, p.height);
  delete[] render;
#endif
}
