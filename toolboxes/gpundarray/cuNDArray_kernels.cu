#include "cuNDArray.h"

template <class T> 
__global__ void cuNDArray_permute_kernel(T* in, T* out, 
					 unsigned int ndim,
					 unsigned int* dims,
					 unsigned int* strides_out,
					 unsigned long int elements)
{
  unsigned long idx_in = blockIdx.x*blockDim.x+threadIdx.x;
  unsigned long idx_out = 0;

  unsigned long idx_in_tmp = idx_in;
  if (idx_in < elements) {
    unsigned int cur_index;
    for (unsigned int i = 0; i < ndim; i++) {
      cur_index = idx_in_tmp%dims[i];
      idx_in_tmp -= cur_index;
      idx_out += cur_index*strides_out[i];
      idx_in_tmp /= dims[i];
    }
    
    out[idx_in] = in[idx_out];
    //out[idx_in] = idx_out;//in[idx_in];
  }

}


template <class T> int cuNDArray_permute(cuNDArray<T>* in,
 					 cuNDArray<T>* out,
					 std::vector<unsigned int> order)
{
  cudaError_t err;

  T* in_ptr = in->data_;
  T* out_ptr = 0;

  if (out) {
    out_ptr = out->data_;
  } else {
    if (cudaMalloc((void**) &out_ptr, in->elements_*sizeof(T)) != cudaSuccess) {
      std::cerr << "cuNDArray_permute : Error allocating CUDA memory" << std::endl;
      out_ptr = 0;
      return -1;
    }
  }

  unsigned int* dims        = new unsigned int[in->dimensions_.size()];
  unsigned int* strides_out = new unsigned int[in->dimensions_.size()];
  if (!dims || !strides_out) {
    std::cerr << "cuNDArray_permute: failed to allocate temporary storage for arrays" << std::endl;
    return -1;
  }

  for (unsigned int i = 0; i < in->dimensions_.size(); i++) {
    dims[i] = in->dimensions_[i];
    strides_out[i] = 1;
    
    for (unsigned int j = 0; j < order[i]; j++) {
      strides_out[i] *= dims[j];
    }
  }

  unsigned int* dims_dev        = 0;
  unsigned int* strides_out_dev = 0;
  
  if (cudaMalloc((void**) &dims_dev, in->dimensions_.size()*sizeof(unsigned int)) != cudaSuccess) {
    std::cerr << "cuNDArray_permute : Error allocating CUDA dims memory" << std::endl;
    return -1;
  }
  
  if (cudaMalloc((void**) &strides_out_dev, in->dimensions_.size()*sizeof(unsigned int)) != cudaSuccess) {
    std::cerr << "cuNDArray_permute : Error allocating CUDA strides_out memory" << std::endl;
    return -1;
  }
  
  if (cudaMemcpy(dims_dev, dims, in->dimensions_.size()*sizeof(unsigned int), cudaMemcpyHostToDevice) !=
      cudaSuccess) {

    err = cudaGetLastError();
    std::cerr << "cuNDArray_permute : Error uploading dimensions to device, " 
	      << cudaGetErrorString(err) << std::endl;
    return -1;
  }

  if (cudaMemcpy(strides_out_dev, strides_out, in->dimensions_.size()*sizeof(unsigned int), cudaMemcpyHostToDevice) !=
      cudaSuccess) {
    std::cerr << "cuNDArray_permute : Error uploading strides to device" << std::endl;
    return -1;
  }

  dim3 blockDim(512,1,1);
  dim3 gridDim((unsigned int) ceil((double)in->elements_/blockDim.x), 1, 1 );

  cuNDArray_permute_kernel<<< gridDim, blockDim >>>( in_ptr, out_ptr, in->dimensions_.size(), 
						     dims_dev, strides_out_dev, in->elements_ );

  err = cudaGetLastError();
  if( err != cudaSuccess ){
    std::cerr << "cuNDArray_permute : Error during kernel call" << std::endl;
    return -1;
  }

  if (cudaFree(dims_dev) != cudaSuccess) {
    std::cerr << "cuNDArray_permute: failed to delete device memory" << std::endl;
    return -1;
  }

  if (cudaFree(strides_out_dev) != cudaSuccess) {
    std::cerr << "cuNDArray_permute: failed to delete device memory" << std::endl;
    return -1;
  }
  
  delete [] dims;
  delete [] strides_out;

  if (!out) {
    std::vector<unsigned int> new_dims;
    for (unsigned int i = 0; i < in->dimensions_.size(); i++) {
      new_dims.push_back(in->dimensions_[order[i]]);
    }
    in->dimensions_ = new_dims;
    if (cudaFree(in->data_) != cudaSuccess) {
	std::cerr << "cuNDArray_permute: failed to delete device memory" << std::endl;
	return -1;
    }
    in->data_ = out_ptr;
  }

  return 0;
}


//Template instanciation
template int cuNDArray_permute<>(cuNDArray<float>* in,
				 cuNDArray<float>* out,
				 std::vector<unsigned int> order);

