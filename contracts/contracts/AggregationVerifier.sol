// SPDX-License-Identifier: AML
//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.

// 2019 OKIMS

pragma solidity ^0.8.0;

import "./Pairing.sol";

contract AggregationVerifier {
    using Pairing for *;

    uint256 constant SNARK_SCALAR_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 constant PRIME_Q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[11] IC;
    }

    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }

    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(uint256(5370341862774682680246466270482025130031920235801467985539884775442069377468), uint256(13798845953998817663090998898736809998792954228523112700202791163842851171724));
        vk.beta2 = Pairing.G2Point([uint256(18213007558649470865533809656831514005064165654030619512731479699648604576154), uint256(15870909698063230275004127440026837587206670287294403229081018622765048705207)], [uint256(19306245284011897573404264414054484857927394828872425031946361816364060775590), uint256(18303379608003818818272009170145995357004135928416220757883414304526854390958)]);
        vk.gamma2 = Pairing.G2Point([uint256(6910856625348543264977908875677268792441541893735674608091086252739398734492), uint256(12516801829959882576400974928665507079613305228564602771294685626705622219145)], [uint256(983626218199389938873520929068652635760544027323065597101376026529148760312), uint256(7822552345929973760847478685710393845821235866353066993068342440565061797299)]);
        vk.delta2 = Pairing.G2Point([uint256(4762328953739296496925200621883459934253877898407853528999792567750680066731), uint256(13499336604179161101648162069178893847978173056056331369836439369160911503845)], [uint256(18375570062616721944366681101522355107146194381089280634167940034680503728083), uint256(9921968925691216622817272083021203690845760446646856697011960849960999026861)]);
        vk.IC[0] = Pairing.G1Point(uint256(1207591220818605294107746037800144463425485296361581111014836505677523785662), uint256(9211065915957336005171409321241472964722056598949617891226975454146018126473));
        vk.IC[1] = Pairing.G1Point(uint256(8431585533739954453481514098873755095501764768426148450921882574712641094999), uint256(2172846286007659188893891581045536337565429624827595241479566930759695312521));
        vk.IC[2] = Pairing.G1Point(uint256(18918769487042580291830356544097390008773542385892486197489710849674485645916), uint256(9240807192789390329511903134493616305033286644650829068064294430537027828668));
        vk.IC[3] = Pairing.G1Point(uint256(10912455801739637926925081089910487306731672618565875013352820467571202344215), uint256(14952765176405325006117505131343029964857944552305636575810287965066871334119));
        vk.IC[4] = Pairing.G1Point(uint256(6506968122274270219641797437108603482630024169554962300517941236121262913107), uint256(14001965228453111862924517006497764293072632456959606030304190586415255296212));
        vk.IC[5] = Pairing.G1Point(uint256(2329958971490540307200221394551590917351307476910131716362829549091653508633), uint256(20042513715036545942009668834092072753017315261124813568421942658021066969493));
        vk.IC[6] = Pairing.G1Point(uint256(12287765708997704165047855159786672989480855481796468271499710057827569982231), uint256(14601527228765785622006880764155993872043259940109033193336335482193442274820));
        vk.IC[7] = Pairing.G1Point(uint256(12036697189431687705976998105533517182877130539890547478697637517571111992449), uint256(8289839713291557600992168929683723326456945567044444568675228648922090017785));
        vk.IC[8] = Pairing.G1Point(uint256(7181770465710919095058900046861299634273589505139875163171028920613960558021), uint256(12685205400410645287501740729944711310727962163572127913690708422735535087179));
        vk.IC[9] = Pairing.G1Point(uint256(6890252419937939986459504647056981869035778902685490559845494965272110295484), uint256(7541409449614595956014630858127652617452608586185140218944637483165673235579));
        vk.IC[10] = Pairing.G1Point(uint256(573942731618829663472823161565903352508771140954587257136794344270240194972), uint256(20135716805594030351104976863882531642041508082812087257086211446520549552453));
    }

    /*
     * @returns Whether the proof is valid given the hardcoded verifying key
     *          above and the public inputs
     */
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[10] memory input
    ) public view returns (bool r) {

        Proof memory proof;
        proof.A = Pairing.G1Point(a[0], a[1]);
        proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.C = Pairing.G1Point(c[0], c[1]);

        VerifyingKey memory vk = verifyingKey();

        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);

        // Make sure that proof.A, B, and C are each less than the prime q
        require(proof.A.X < PRIME_Q, "verifier-aX-gte-prime-q");
        require(proof.A.Y < PRIME_Q, "verifier-aY-gte-prime-q");

        require(proof.B.X[0] < PRIME_Q, "verifier-bX0-gte-prime-q");
        require(proof.B.Y[0] < PRIME_Q, "verifier-bY0-gte-prime-q");

        require(proof.B.X[1] < PRIME_Q, "verifier-bX1-gte-prime-q");
        require(proof.B.Y[1] < PRIME_Q, "verifier-bY1-gte-prime-q");

        require(proof.C.X < PRIME_Q, "verifier-cX-gte-prime-q");
        require(proof.C.Y < PRIME_Q, "verifier-cY-gte-prime-q");

        // Make sure that every input is less than the snark scalar field
        for (uint256 i = 0; i < input.length; i++) {
            require(input[i] < SNARK_SCALAR_FIELD,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.plus(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }

        vk_x = Pairing.plus(vk_x, vk.IC[0]);

        return Pairing.pairing(
            Pairing.negate(proof.A),
            proof.B,
            vk.alfa1,
            vk.beta2,
            vk_x,
            vk.gamma2,
            proof.C,
            vk.delta2
        );
    }
}