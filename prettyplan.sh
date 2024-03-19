#!/bin/bash

MIN_DIFF_THRESHOLD=5

if ! [ -e plan.binary ]; then
  echo "plan.binary missing!  Did you run a plan?  You should run a plan first!"
else
  PLAN_TIMESTAMP=$(date -r plan.binary)
  PLAN_TIMESTAMP_SEC=$(date --date="${PLAN_TIMESTAMP}" +%s)
  NOW_SEC=$(date +%s)
  MIN_DIFF=$(( ( NOW_SEC - PLAN_TIMESTAMP_SEC ) / 60 ))
  echo "Running prettyplan.sh against plan.binary.. last updated: $(date -r plan.binary) ( ~ $MIN_DIFF Minutes Ago )"
  if [[ MIN_DIFF -gt MIN_DIFF_THRESHOLD ]]; then
    echo
    echo '|| || || || || || || || || || || || || || || || || || || || || ||'
    echo '\/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/'
    echo "  *** Are you sure!?!? The plan.binary is $MIN_DIFF Minutes old! ***"
    echo "    I mean, I'll still show you the pretty plan, but you"
    echo "    maybe, probably want to run a clean plan refresh, no?"
    echo '/\ /\ /\ /\ /\ /\ /\ /\ /\ /\ /\ /\ /\ /\ /\ /\ /\ /\ /\ /\ /\ /\'
    echo '|| || || || || || || || || || || || || || || || || || || || || ||'
    echo
  fi
fi

terragrunt show --json plan.binary 2>/dev/null | tee plan.json | jq -r '

  # pull out changes only
  ([.resource_changes[]?])

  |

  # filter out no-op changes
  map(select(.change.actions!=["no-op"]))

  |

  # create pretty array of changes
  # options documented at https://pkg.go.dev/github.com/hashicorp/terraform-json?tab=doc
  # New Documentation: https://www.terraform.io/docs/internals/json-format.html#plan-representation

  [ 
    [["Operation", "Provider", "Resource Type", "Module Address", "Index ID", "Full Resource ID"]],
    [["---------", "--------", "-------------", "--------------", "--------", "----------------"]],
    (map(select(.change.actions==["create"]         )) | map(["Create",                 .provider_name, .type, .module_address?, .index?, .address]) ),
    (map(select(.change.actions==["update"]         )) | map(["Update",                 .provider_name, .type, .module_address?, .index?, .address]) ),
    (map(select(.change.actions==["delete"]         )) | map(["!!DESTROY!!",            .provider_name, .type, .module_address?, .index?, .address]) ),

    # Note that both these are a "Replace" operation.  I prefer knowing which kind of replace is happening explicitly.
    (map(select(.change.actions==["create","delete"])) | map(["Replace - Create before Destroy",  .provider_name, .type, .module_address?, .index?, .address]) ),
    (map(select(.change.actions==["delete","create"])) | map(["Replace - Destroy before Create",  .provider_name, .type, .module_address?, .index?, .address]) )
  ]

  # Unnest arrays for @tsv
  | .[] | .[]

  # Convert to Tab Delimited
  | @tsv

  # column will convert tabs to spaces and make it pretty
  ' | column -s $'\t' -n -t | tee prettyplan.txt

echo
echo "*** This PrettyPlan output has been saved to ./prettyplan.txt ! (so you don't have to run this again) ***"
echo
