#include <bits/stdc++.h>
using namespace std;

int main() {
    ios_base::sync_with_stdio(false);
    cin.tie(nullptr);

    int n;
    cin >> n;

    vector<int> a(n);
    for (auto &x : a) cin >> x;

    long long sum = 0;
    for (int x : a) sum += x;

    cout << "n = " << n << "\n";
    cout << "sum = " << sum << "\n";

    return 0;
}
