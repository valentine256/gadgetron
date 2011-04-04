#include "CropAndCombineGadget.h"


int CropAndCombineGadget::
process( GadgetContainerMessage<GadgetMessageImage>* m1,
	 GadgetContainerMessage< NDArray< std::complex<float> > >* m2)
{


  GadgetContainerMessage< NDArray< std::complex<float> > >* m3 = 
    new GadgetContainerMessage< NDArray< std::complex<float> > >();

  std::vector<int> new_dimensions(3);
  new_dimensions[0] = m2->getObjectPtr()->get_size(0)>>1;
  new_dimensions[1] = m2->getObjectPtr()->get_size(1);
  new_dimensions[2] = m2->getObjectPtr()->get_size(2);

  if (!m3->getObjectPtr()->create(new_dimensions)) {
    ACE_DEBUG( (LM_ERROR, 
		ACE_TEXT("CropAndCombineGadget, failed to allocate new array\n")) );
    m1->release();
    return -1;
  }

  int dimx     = m3->getObjectPtr()->get_size(0);
  int dimx_old = m2->getObjectPtr()->get_size(0);

  int dimy = m3->getObjectPtr()->get_size(1);
  int dimz = m3->getObjectPtr()->get_size(2);

  int channels = m2->getObjectPtr()->get_size(3);

  std::complex<float>* d1 = m2->getObjectPtr()->get_data_ptr();
  std::complex<float>* d2 = m3->getObjectPtr()->get_data_ptr();

  size_t img_block_old = dimx_old*dimy*dimz;

  for (int z = 0; z < dimz; z++) {
    for (int y = 0; y < dimy; y++) {
      for (int x = 0; x < dimx; x++) {
	float mag = 0;
	float phase = 0;
	size_t offset_1 = z*dimy*dimx_old+y*dimx_old+x+((dimx_old-dimx)>>1);
	size_t offset_2 = z*dimy*dimx+y*dimx+x;
	for (int c = 0; c < channels; c++) {
	  //ACE_DEBUG( (LM_DEBUG, ACE_TEXT("%@, %@\n"), d1,d2) );
	  //ACE_DEBUG( (LM_DEBUG, ACE_TEXT("%d, %d\n"), 
	  //	      m2->getObjectPtr()->get_number_of_elements(),
	  //	      m3->getObjectPtr()->get_number_of_elements()) );
	  
	  //ACE_DEBUG( (LM_DEBUG, 
	  //	      ACE_TEXT("c = %d, offset_1 = %d, dimx = %d, dimy = %d, dimz = %d, dimx_old = %d\n"),
	  //	      c, offset_1, dimx, dimy, dimz, dimx_old) );
	  float mag_tmp = norm(d1[offset_1 + c*img_block_old]);
	  phase += mag_tmp*arg(d1[offset_1 + c*img_block_old]);
	  mag += mag_tmp;
	}

	d2[offset_2] = std::polar((float)sqrt(mag),phase);
      }
    }
  }

  //Now add the new array to the outgoing message
  m1->cont(m3);
  m2->release();

  //Modify header to match
  m1->getObjectPtr()->matrix_size[0] = m1->getObjectPtr()->matrix_size[0]>>1;
  m1->getObjectPtr()->channels = 1;

  return this->next()->putq(m1);
}

GADGET_FACTORY_DECLARE(CropAndCombineGadget)