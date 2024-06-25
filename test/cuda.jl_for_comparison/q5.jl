function dequantize_q5_kernel(y, x, nb,)
    idx = threadIdx().x + (blockIdx().x - 1) * blockDim().x
    if idx <= nb
        d = Float32(x[idx].d)
        dmin = Float32(x[idx].dmin)
        ql = x[idx].qs
        qh = x[idx].qh
        scales = x[idx].scales

        for il in 0:3
            for ir in 0:15
                is = 2 * il + 1
                offset = (idx - 1) * 256 + 64 * il + 2 * ir + 1
                ql_index = 32 * il + 2 * ir + 1
                qh_index = 2 * ir + 1

                sc1, m1 = get_scale_min_k4(is, scales)
                d1 = d * sc1
                min1 = dmin * m1

                sc2, m2 = get_scale_min_k4(is + 1, scales)
                d2 = d * sc2
                min2 = dmin * m2

                hm = UInt8(1 << (2 * il))

                y[offset] = d1 * ((ql[ql_index] & 0xF) + (qh[qh_index] & hm != 0 ? 16.0 : 0.0)) - min1
                y[offset + 1] = d1 * ((ql[ql_index + 1] & 0xF) + (qh[qh_index + 1] & hm != 0 ? 16.0 : 0.0)) - min1
                hm <<= 1
                y[offset + 32] = d2 * ((ql[ql_index] >> 4) + (qh[qh_index] & hm != 0 ? 16.0 : 0.0)) - min2
                y[offset + 33] = d2 * ((ql[ql_index + 1] >> 4) + (qh[qh_index + 1] & hm != 0 ? 16.0 : 0.0)) - min2
            end
        end
    end
end

function dequantize_cuda!(y::CuVector{Float16}, x::CuVector{block_q5_K})
  k = length(y)
  @assert k % QK_K == 0
  nb = k ÷ QK_K

  threads_per_block = 256
  blocks_per_grid = ceil(Int, nb / threads_per_block)

  @cuda threads=threads_per_block blocks=blocks_per_grid dequantize_q5_kernel(y, x, nb,)

  return y
end
