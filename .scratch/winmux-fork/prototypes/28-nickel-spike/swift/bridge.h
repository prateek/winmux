typedef struct Engine Engine;
Engine *wm_load(const char *path, char **err);
char *wm_call(Engine *e, const char *request);
void wm_free_string(char *s);
void wm_free(Engine *e);
