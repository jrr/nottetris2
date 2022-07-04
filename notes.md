Trying to build old version of Love (0.7.2). Started with latest Ubuntu LTS
(22.04), got most of the dependencies installed, but hitting problems with some
OpenGL things:

```
DEPDIR=.deps depmode=none /bin/bash ../platform/unix/depcomp \
g++ -DHAVE_CONFIG_H   -I. -I./modules -I/usr/include/AL -I/usr/include/freetype2  -I/usr/include/lua5.1 -I/usr/include/SDL -D_FILE_OFFSET_BITS=64    -c -o modules/graphics/opengl/Framebuffer.o modules/graphics/opengl/Framebuffer.cpp
modules/graphics/opengl/Framebuffer.cpp: In member function 'virtual GLenum love::graphics::opengl::FramebufferStrategyGL3::createFBO(GLuint&, GLuint&, GLuint&, int, int)':
modules/graphics/opengl/Framebuffer.cpp:45:25: error: 'glGenRenderbuffers' was not declared in this scope
   45 |                         glGenRenderbuffers(1, &depthbuffer);
      |                         ^~~~~~~~~~~~~~~~~~
```

Next trying older Ubuntus.
