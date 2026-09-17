function item = get_environment_candidate(candidateId)
%GET_ENVIRONMENT_CANDIDATE Return one catalog item by ID, case-insensitive.
C = environment_catalog();
idx = find(strcmpi({C.id},strtrim(candidateId)),1);
if isempty(idx)
    error('get_environment_candidate:UnknownID','Unknown candidate ID: %s',candidateId);
end
item = C(idx);
end
