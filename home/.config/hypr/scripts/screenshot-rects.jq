# Only windows currently visible on connected monitors can be selected.
.[] as $window
| select($window.mapped != false and $window.hidden != true)
| select(
    $window.pinned == true
    or any($monitors[];
        .activeWorkspace.id == $window.workspace.id
        or ((.specialWorkspace.id // 0) != 0 and .specialWorkspace.id == $window.workspace.id)
    )
)
| select(($window.at | length) == 2 and ($window.size | length) == 2)
| select($window.size[0] > 0 and $window.size[1] > 0)
| "\($window.at[0] | floor),\($window.at[1] | floor) \($window.size[0] | floor)x\($window.size[1] | floor)"
