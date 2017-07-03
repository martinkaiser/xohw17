/*
The MIT License

Copyright (c) 2017 Florian Porrmann

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

#include <nmmintrin.h>
#include <stdint.h>
#ifdef _WIN32
#include <intrin.h>
#else
#include <x86intrin.h>
#endif
#include <string>
#include <vector>
#include <iostream>
#include <iomanip>
#include <fstream>

#include "Timer.h"

typedef uint8_t byte;
typedef std::vector<byte> bytes;


typedef union
{
	__m256i             value;
	int8_t              m256i_i8[32];
	int16_t             m256i_i16[16];
	int32_t             m256i_i32[8];
	int64_t             m256i_i64[4];
	uint8_t             m256i_u8[32];
	uint16_t            m256i_u16[16];
	uint32_t            m256i_u32[8];
	uint64_t            m256i_u64[4];
} __m256i_c;

struct hash
{
	union
	{
		uint8_t bytes[64];
		uint64_t quadWords[8];
		__m256i_c octaWords[2];

	} vals;

	hash operator^(const hash& h1)
	{
		hash res;
		for (int i = 0; i < 64; i++)
			res.vals.bytes[i] = this->vals.bytes[i] ^ h1.vals.bytes[i];

		return res;
	}

	friend std::ostream& operator<<(std::ostream& stream, const hash &h)
	{
		for (int i = 0; i < 64; i++)
			stream << std::hex << std::setfill('0') << std::setw(2) << std::nouppercase << (int)h.vals.bytes[i];

		return stream;
	}
};



uint8_t popCnt8(uint8_t uc)
{
	uint8_t n;
	n = ((uc >> 1) & 0x55) + (uc & 0x55);
	n = ((n >> 2) & 0x33) + (n & 0x33);
	return (n >> 4) + (n & 0x0f);
}

uint32_t popCnt512(hash n)
{
	uint32_t res = 0;

	for (int i = 0; i < 64; i++)
		res += popCnt8(n.vals.bytes[i]);

	return res;
}



uint64_t popcount256(const uint64_t* u)
{
	return _mm_popcnt_u64(u[0]) + _mm_popcnt_u64(u[1]) + _mm_popcnt_u64(u[2]) + _mm_popcnt_u64(u[3]);
}

uint32_t hamming512(hash a, hash b)
{
	uint64_t res = 0;
	__m256i_c v;
	v.value = _mm256_xor_si256(a.vals.octaWords[0].value, b.vals.octaWords[0].value);
	res += popcount256(v.m256i_u64);
	v.value = _mm256_xor_si256(a.vals.octaWords[1].value, b.vals.octaWords[1].value);
	res += popcount256(v.m256i_u64);
	return (uint32_t)res;
}

struct Result
{
	uint64_t val;

	uint16_t dist;
	uint32_t idxB;
	uint32_t idxA;

	Result(uint64_t v)
	{
		val = v;
		CalcValues();
	}

	void CalcValues()
	{
		dist = (uint16_t)val & 0x3FF;
		idxB = (uint32_t)(val >> 10) & 0x7FFFFFF;
		idxA = (uint32_t)(val >> 37) & 0x7FFFFFF;
	}

};

int fromHex(char _i)
{
	if (_i >= '0' && _i <= '9')
		return _i - '0';
	if (_i >= 'a' && _i <= 'f')
		return _i - 'a' + 10;
	if (_i >= 'A' && _i <= 'F')
		return _i - 'A' + 10;

	return -1;
}

bytes hexStringToBytes(std::string const& _s)
{
	unsigned s = (_s[0] == '0' && _s[1] == 'x') ? 2 : 0;
	std::vector<uint8_t> ret;
	ret.reserve((_s.size() - s + 1) / 2);

	if (_s.size() % 2)
	{
		try
		{
			ret.push_back(fromHex(_s[s++]));
		}
		catch (...)
		{
			ret.push_back(0);
		}
	}

	for (unsigned i = s; i < _s.size(); i += 2)
	{
		try
		{
			ret.push_back((byte)(fromHex(_s[i]) * 16 + fromHex(_s[i + 1])));
		}
		catch (...)
		{
			ret.push_back(0);
		}
	}

	return ret;
}

hash stringToHash(std::string const& _s)
{
	hash ret;
	bytes b = hexStringToBytes(_s);
	memcpy(&ret.vals.bytes, b.data(), b.size());
	return ret;
}

std::string hps(double val)
{
	std::string str = "";
	int cnt = 0;

	while (val / 1000.0 > 1.0)
	{
		val /= 1000.0;
		cnt++;
	}

#ifdef _WIN32
	str.append(std::_Floating_to_string("%0.3f", val));
#else
	str.append(std::to_string(val));
#endif

	switch (cnt)
	{
		// hash per second
	case 0:
		str.append(" h/s");
		break;

		// kilo hash per second
	case 1:
		str.append(" Kh/s");
		break;

		// mega hash per second
	case 2:
		str.append(" Mh/s");
		break;

		// giga hash per second
	case 3:
		str.append(" Gh/s");
		break;

		// tera hash per second
	case 4:
		str.append(" Th/s");
		break;
	}

	return str;
}


int main(int argc, char **argv)
{
	// --------- LOAD INPUT DATA ---------
	Timer execTimer;
	execTimer.start();

	std::vector<hash> staticData;
	std::vector<hash> dynData;

	std::ifstream infile("a.txt");

	if (!infile.is_open())
	{
		std::cout << "Error while opening the input file. Current Directory: " << system("dir") << std::endl;
		return -1;
	}

	std::string s;
	while (infile >> s)
		staticData.push_back(stringToHash(s));

	infile.close();
	infile.open("b_1m.txt");

	if (!infile.is_open())
	{
		std::cout << "Error while opening the input file. Current Directory: " << system("dir") << std::endl;
		return -1;
	}

	while (infile >> s)
		dynData.push_back(stringToHash(s));

	printf("---Static Data(%llu)---\nFirst: ", staticData.size());

	for (int j = 0; j < 64; j++)
		printf("%02x", staticData.front().vals.bytes[j]);

	printf("\nLast:  ");

	for (int j = 0; j < 64; j++)
		printf("%02x", staticData.back().vals.bytes[j]);

	printf("\n");

	printf("---Dynamic Data(%llu)---\nFirst: ", dynData.size());

	for (int j = 0; j < 64; j++)
		printf("%02x", dynData.front().vals.bytes[j]);

	printf("\nLast:  ");

	for (int j = 0; j < 64; j++)
		printf("%02x", dynData.back().vals.bytes[j]);

	printf("\n");

	execTimer.stop();
	printf("Input data load time: %0.3f ms\n", execTimer.getElapsedTimeInMilliSec());

	// --------- LOAD INPUT DATA ---------

	uint64_t bla = 0;

	execTimer.start();
	int i;

#pragma omp parallel shared(bla) private(i)
	{
#pragma omp for schedule(dynamic)
		for (i = 0; i < dynData.size(); i++)
		{
			for (int j = 0; j < staticData.size(); j++)
			{
				// Just add up the results to prevent the compiler from
				// removing everything
				bla += hamming512(staticData.at(j), dynData.at(i));
			}
		}
	}

	execTimer.stop();

	printf("Compute time: %0.3f ms\n", execTimer.getElapsedTimeInMilliSec());
	printf("Hashes per second: %s\n", hps((staticData.size() * dynData.size()) / (execTimer.getElapsedTimeInMilliSec() / 1000.0)).c_str());

	// Print the add up result to prevent compiler stuff
	printf("res: %llu\n", bla);

	return 0;
}