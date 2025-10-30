#pragma once
#include <vector>

// FrameData: đại diện cho một frame dữ liệu trong một record
struct FrameData {
    int frameIdx;            // Chỉ số frame trong record
    double depth;            // Độ sâu (nếu có)
    int recordIdx;           // Chỉ số record chứa frame này
    std::vector<double> values; // Mảng giá trị đo (từ các kênh/curve)

    FrameData()
        : frameIdx(0), depth(0), recordIdx(0) {}
};
