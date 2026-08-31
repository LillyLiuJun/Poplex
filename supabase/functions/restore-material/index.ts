import { createMaterialMutationHandler } from "../_shared/materialMutation.ts";

Deno.serve(createMaterialMutationHandler("restore"));
