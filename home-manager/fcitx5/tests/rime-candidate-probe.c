#include <rime_api.h>
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
  if(argc != 5) return 2;
  RimeApi *api = rime_get_api();
  RIME_STRUCT(RimeTraits, traits);
  traits.shared_data_dir = argv[1];
  traits.user_data_dir = argv[2];
  traits.app_name = "rime.xhup-add-test";
  api->setup(&traits);
  api->initialize(&traits);
  RimeSessionId session = api->create_session();
  if (!session || !api->select_schema(session, "xhup")) return 3;
  api->simulate_key_sequence(session, argv[3]);
  RIME_STRUCT(RimeContext, context);
  int found = 0;
  if (api->get_context(session, &context)) {
    for (int i=0; i<context.menu.num_candidates; i++) {
      puts(context.menu.candidates[i].text);
      found |= strcmp(context.menu.candidates[i].text, argv[4]) == 0;
    }
    api->free_context(&context);
  }
  api->destroy_session(session);
  api->finalize();
  return found ? 0 : 4;
}
