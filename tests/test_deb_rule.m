function test_deb_rule()
%TEST_DEB_RULE 验证可行性优先、CV 优先和可行目标优先。
a=result_stub(10,0);a.isFeasible=true;
% [逐行说明] 计算或更新 `b`，供后续算法、评价或日志步骤使用。
b=result_stub(1,0.5);b.isFeasible=false;
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(deb_better(a,b));assert(~deb_better(b,a));
% [逐行说明] 计算或更新 `c`，供后续算法、评价或日志步骤使用。
c=result_stub(5,0);c.isFeasible=true;
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(deb_better(c,a));
% [逐行说明] 计算或更新 `d`，供后续算法、评价或日志步骤使用。
d=result_stub(100,0.2);d.isFeasible=false;
% [逐行说明] 计算或更新 `e`，供后续算法、评价或日志步骤使用。
e=result_stub(1,0.3);e.isFeasible=false;
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(deb_better(d,e));
end
