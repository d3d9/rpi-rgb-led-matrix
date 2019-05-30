# distutils: language = c++

from libcpp cimport bool
from libc.stdint cimport uint8_t, uint32_t, uintptr_t
from PIL import Image
import cython

cdef class GPIO:
    cdef cppinc.GPIO* gpio(self) except +:
        raise Exception("Not implemented")

    cdef uint32_t RequestInputs(self, uint32_t inputs):
        raise Exception("Not implemented")

cdef class Canvas:
    cdef cppinc.Canvas* __getCanvas(self) except +:
        raise Exception("Not implemented")

    def SetImage(self, image, int offset_x = 0, int offset_y = 0, unsafe=True, transp=False):
        if (image.mode != "RGB"):
            raise Exception("Currently, only RGB mode is supported for SetImage(). Please create images with mode 'RGB' or convert first with image = image.convert('RGB'). Pull requests to support more modes natively are also welcome :)")

        if unsafe:
            #In unsafe mode we directly access the underlying PIL image array
            #in cython, which is considered unsafe pointer accecss,
            #however it's super fast and seems to work fine
            #https://groups.google.com/forum/#!topic/cython-users/Dc1ft5W6KM4
            img_width, img_height = image.size
            self.SetPixelsPillow(offset_x, offset_y, img_width, img_height, image, transp)
        else:
            # First implementation of a SetImage(). OPTIMIZE_ME: A more native
            # implementation that directly reads the buffer and calls the underlying
            # C functions can certainly be faster.
            img_width, img_height = image.size
            pixels = image.load()
            for x in range(max(0, -offset_x), min(img_width, self.width - offset_x)):
                for y in range(max(0, -offset_y), min(img_height, self.height - offset_y)):
                    (r, g, b) = pixels[x, y]
                    if (not transp) or (r > 0 or g > 0 or b > 0):
                        self.SetPixel(x + offset_x, y + offset_y, r, g, b)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def SetPixelsPillow(self, int xstart, int ystart, int width, int height, image, transp=False):
        cdef cppinc.FrameCanvas* my_canvas = <cppinc.FrameCanvas*>self.__getCanvas()
        cdef int frame_width = my_canvas.width()
        cdef int frame_height = my_canvas.height()
        cdef int row, col
        cdef uint8_t r, g, b
        cdef uint32_t **image_ptr
        cdef uint32_t pixel
        image.load()
        ptr_tmp = dict(image.im.unsafe_ptrs)['image32']
        image_ptr = (<uint32_t **>(<uintptr_t>ptr_tmp))

        for col in range(max(0, -xstart), min(width, frame_width - xstart)):
            for row in range(max(0, -ystart), min(height, frame_height - ystart)):
                pixel = image_ptr[row][col]
                r = (pixel ) & 0xFF
                g = (pixel >> 8) & 0xFF
                b = (pixel >> 16) & 0xFF
                if (not transp) or (r > 0 or g > 0 or b > 0):
                    my_canvas.SetPixel(xstart+col, ystart+row, r, g, b)

cdef class FrameCanvas(Canvas):
    def __dealloc__(self):
        if <void*>self.__canvas != NULL:
            self.__canvas = NULL

    cdef cppinc.Canvas* __getCanvas(self) except *:
        if <void*>self.__canvas != NULL:
            return self.__canvas
        raise Exception("Canvas was destroyed or not initialized, you cannot use this object anymore")

    def Fill(self, uint8_t red, uint8_t green, uint8_t blue):
        (<cppinc.FrameCanvas*>self.__getCanvas()).Fill(red, green, blue)

    def Clear(self):
        (<cppinc.FrameCanvas*>self.__getCanvas()).Clear()

    def ppm(self, filename=None):
        if filename:
            if not (<cppinc.FrameCanvas*>self.__getCanvas()).ppm(filename.encode('utf-8')):
                raise Exception("Couldn't write ppm to " + filename)
        else:
            return (<cppinc.FrameCanvas*>self.__getCanvas()).ppm()

    def SetPixel(self, int x, int y, uint8_t red, uint8_t green, uint8_t blue):
        (<cppinc.FrameCanvas*>self.__getCanvas()).SetPixel(x, y, red, green, blue)


    property width:
        def __get__(self): return (<cppinc.FrameCanvas*>self.__getCanvas()).width()

    property height:
        def __get__(self): return (<cppinc.FrameCanvas*>self.__getCanvas()).height()

    property pwmBits:
        def __get__(self): return (<cppinc.FrameCanvas*>self.__getCanvas()).pwmbits()
        def __set__(self, pwmBits): (<cppinc.FrameCanvas*>self.__getCanvas()).SetPWMBits(pwmBits)

    property brightness:
        def __get__(self): return (<cppinc.FrameCanvas*>self.__getCanvas()).brightness()
        def __set__(self, val): (<cppinc.FrameCanvas*>self.__getCanvas()).SetBrightness(val)


cdef class RGBMatrixOptions:
    def __cinit__(self):
        self.__options = cppinc.Options()
        self.__runtime_options = cppinc.RuntimeOptions()

    # RGBMatrix::Options properties
    property hardware_mapping:
        def __get__(self): return self.__options.hardware_mapping
        def __set__(self, value):
            self.__py_encoded_hardware_mapping = value.encode('utf-8')
            self.__options.hardware_mapping = self.__py_encoded_hardware_mapping

    property rows:
        def __get__(self): return self.__options.rows
        def __set__(self, uint8_t value): self.__options.rows = value

    property cols:
        def __get__(self): return self.__options.cols
        def __set__(self, uint8_t value): self.__options.cols = value

    property chain_length:
        def __get__(self): return self.__options.chain_length
        def __set__(self, uint8_t value): self.__options.chain_length = value

    property parallel:
        def __get__(self): return self.__options.parallel
        def __set__(self, uint8_t value): self.__options.parallel = value

    property pwm_bits:
        def __get__(self): return self.__options.pwm_bits
        def __set__(self, uint8_t value): self.__options.pwm_bits = value

    property pwm_lsb_nanoseconds:
        def __get__(self): return self.__options.pwm_lsb_nanoseconds
        def __set__(self, uint32_t value): self.__options.pwm_lsb_nanoseconds = value

    property brightness:
        def __get__(self): return self.__options.brightness
        def __set__(self, uint8_t value): self.__options.brightness = value

    property scan_mode:
        def __get__(self): return self.__options.scan_mode
        def __set__(self, uint8_t value): self.__options.scan_mode = value

    property multiplexing:
        def __get__(self): return self.__options.multiplexing
        def __set__(self, uint8_t value): self.__options.multiplexing = value

    property row_address_type:
        def __get__(self): return self.__options.row_address_type
        def __set__(self, uint8_t value): self.__options.row_address_type = value

    property disable_hardware_pulsing:
        def __get__(self): return self.__options.disable_hardware_pulsing
        def __set__(self, value): self.__options.disable_hardware_pulsing = value

    property show_refresh_rate:
        def __get__(self): return self.__options.show_refresh_rate
        def __set__(self, value): self.__options.show_refresh_rate = value

    property inverse_colors:
        def __get__(self): return self.__options.inverse_colors
        def __set__(self, value): self.__options.inverse_colors = value

    property led_rgb_sequence:
        def __get__(self): return self.__options.led_rgb_sequence
        def __set__(self, value):
            self.__py_encoded_led_rgb_sequence = value.encode('utf-8')
            self.__options.led_rgb_sequence = self.__py_encoded_led_rgb_sequence

    property pixel_mapper_config:
        def __get__(self): return self.__options.pixel_mapper_config
        def __set__(self, value):
            self.__py_encoded_pixel_mapper_config = value.encode('utf-8')
            self.__options.pixel_mapper_config = self.__py_encoded_pixel_mapper_config

    property pixelsvector:
        def __get__(self): return self.__options.pixelsvector
        def __set__(self, value): self.__options.pixelsvector = value

    property pwm_dither_bits:
        def __get__(self): return self.__options.pwm_dither_bits
        def __set__(self, uint8_t value): self.__options.pwm_dither_bits = value


    # RuntimeOptions properties

    property gpio_slowdown:
        def __get__(self): return self.__runtime_options.gpio_slowdown
        def __set__(self, uint8_t value): self.__runtime_options.gpio_slowdown = value

    property daemon:
        def __get__(self): return self.__runtime_options.daemon
        def __set__(self, uint8_t value): self.__runtime_options.daemon = value

    property drop_privileges:
        def __get__(self): return self.__runtime_options.drop_privileges
        def __set__(self, uint8_t value): self.__runtime_options.drop_privileges = value

cdef class RGBMatrix(Canvas):
    def __cinit__(self, int rows = 0, int chains = 0, int parallel = 0,
        RGBMatrixOptions options = None):

        # If RGBMatrixOptions not provided, create defaults and set any optional
        # parameters supplied
        if options == None:
            options = RGBMatrixOptions()

        if rows > 0:
            options.rows = rows
        if chains > 0:
            options.chain_length = chains
        if parallel > 0:
            options.parallel = parallel

        self.__matrix = cppinc.CreateMatrixFromOptions(options.__options,
            options.__runtime_options)

    def __dealloc__(self):
        self.__matrix.Clear()
        del self.__matrix

    cdef cppinc.Canvas* __getCanvas(self) except *:
        if <void*>self.__matrix != NULL:
            return self.__matrix
        raise Exception("Canvas was destroyed or not initialized, you cannot use this object anymore")

    cdef cppinc.GPIO* gpio(self):
        # ... ?
        return self.__matrix.gpio()

    def Fill(self, uint8_t red, uint8_t green, uint8_t blue):
        self.__matrix.Fill(red, green, blue)

    def SetPixel(self, int x, int y, uint8_t red, uint8_t green, uint8_t blue):
        self.__matrix.SetPixel(x, y, red, green, blue)

    def Clear(self):
        self.__matrix.Clear()

    def CreateFrameCanvas(self, pixelsvector=0):
        return __createFrameCanvas(self.__matrix.CreateFrameCanvas(pixelsvector))

    def SwapOnVSync(self, FrameCanvas newFrame):
        return __createFrameCanvas(self.__matrix.SwapOnVSync(newFrame.__canvas))

    def GPIORequestInputs(self, uint32_t inputs):
        return self.gpio().RequestInputs(inputs)

    def AwaitInputChange(self, int timeout_ms):
        return self.__matrix.AwaitInputChange(timeout_ms)

    property luminanceCorrect:
        def __get__(self): return self.__matrix.luminance_correct()
        def __set__(self, luminanceCorrect): self.__matrix.set_luminance_correct(luminanceCorrect)

    property pwmBits:
        def __get__(self): return self.__matrix.pwmbits()
        def __set__(self, pwmBits): self.__matrix.SetPWMBits(pwmBits)

    property brightness:
        def __get__(self): return self.__matrix.brightness()
        def __set__(self, brightness): self.__matrix.SetBrightness(brightness)

    property height:
        def __get__(self): return self.__matrix.height()

    property width:
        def __get__(self): return self.__matrix.width()

cdef __createFrameCanvas(cppinc.FrameCanvas* newCanvas, bool pixelsvector=0):
    canvas = FrameCanvas(pixelsvector)
    canvas.__canvas = newCanvas
    return canvas

# Local Variables:
# mode: python
# End:
