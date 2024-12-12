\c pongfumasters

CREATE SCHEMA partman;

SELECT pg_partman.create_parent(
    p_parent_table := 'public.Users',
    p_control := 'created_at',
    p_type := 'time',
    p_interval := 'monthly',
    p_premake := 3,
    p_use_run_maintenance := true
    p_inherit
)

SELECT partman.create_parent(
    p_parent_table := 'public.Matches',
    p_control := 'started_at',
    p_type := 'time',
    p_interval := 'monthly',
    p_premake := 3,
    p_use_run_maintenance := true
);

SELECT partman.create_parent(
    p_parent_table := 'public.Tournaments',
    p_control := 'started_at',
    p_type := 'time',
    p_interval := 'monthly',
    p_premake := 3,
    p_use_run_maintenance := true
);

SELECT partman.create_parent(
    p_parent_table := 'public.Friendships',
    p_control := 'created_at',
    p_type := 'time',
    p_interval := 'monthly',
    p_premake := 3,
    p_use_run_maintenance := true
);

SELECT partman.create_parent(
    p_parent_table := 'public.UserMatches',
    p_control := 'created_at',
    p_type := 'time',
    p_interval := 'monthly',
    p_premake := 3,
    p_use_run_maintenance := true
);

SELECT partman.create_parent(
    p_parent_table := 'public.UserTournaments',
    p_control := 'created_at',
    p_type := 'time',
    p_interval := 'monthly',
    p_premake := 3,
    p_use_run_maintenance := true
);

