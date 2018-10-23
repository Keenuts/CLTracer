#include <CL/cl.hpp>

#include "app.h"

int main() {
  app_t app = app_t();
  if (app.add_kernel("kern/kernel.cl"))
    return 1;
  app.render();

  printf("[INFO] Done.\n");
  return 0;
}
