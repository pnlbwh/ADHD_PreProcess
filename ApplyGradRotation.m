function bvecs = ApplyGradRotation(bvecs,input_matrix)

%this function is based on the python Pipeline at PNL
%

mrtx = load(input_matrix);

%assume RAS orientation
% if other_info.bvecStd_space(1) == 'L'
%     spctoras = [-1 0 0;0 -1 0;0 0 1];
% else
%     spctoras = eye(3);
% end

mrtx = mrtx(1:3,1:3);

%if identity matrix
if ~((det(mrtx) < 1-1e-5) || (det(mrtx) > 1+1e-5))
    return;
end

rot = mrtx*mrtx';
[U, L, V] = svd(rot);
eL = sqrt(L);
rot = U*eL*V';


bvecs = rot*bvecs;
end