#pragma once

#include <CL/cl.hpp>

class app_t {
  private:
    cl::Context m_context;
    cl::Device m_device;
    cl::Platform m_platform;
    std::vector<cl::Program> m_kernels;

  public:
    app_t();
    int add_kernel(const char* filename);
    void render();

};

