function y = apply_dv(dv_fun, X)
% APPLY_DV  Apply a quad2fun decision-variable handle to each row of X.
    y = zeros(size(X, 1), 1);
    for i = 1:size(X, 1)
        y(i) = dv_fun(X(i, :)');
    end
end
