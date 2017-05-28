#include <chrono>

struct scoped_timer
{
    scoped_timer(double& seconds) : seconds(seconds) {
        t0 = std::chrono::steady_clock::now();
    }

    ~scoped_timer() {
        auto t1 = std::chrono::steady_clock::now();
        std::chrono::duration<double> diff = t1 - t0;
        seconds = diff.count();
    }

    double& seconds;
    std::chrono::steady_clock::time_point t0;
};
