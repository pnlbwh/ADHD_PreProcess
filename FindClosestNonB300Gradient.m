function [before, after] = FindClosestNonB300Gradient(dwi_qc, bval, position, Blimit)

% Return -1 if not found
before = -1;
after = -1;

% Check length
if (length(dwi_qc) ~= length(bval))
   disp('ERROR: sizes of dwi_qc and bval must match') ;
   return;
end

% Search before
for i=position-1:-1:1
    if (dwi_qc(i) == 1) && (bval(i) < Blimit)
       before = i;
       break;
    end
end

% Search after
for i=position+1:length(dwi_qc)
    if (dwi_qc(i) == 1) && (bval(i) < Blimit)
       after = i;
       break;
    end
end


end