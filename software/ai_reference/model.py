"""Small, explicit CNN used as the independent desktop reference."""

from __future__ import annotations

from collections import OrderedDict

import torch
from torch import Tensor, nn
import torch.nn.functional as F


ARCHITECTURE = {
    "input": [1, 28, 28],
    "conv1": {
        "in_channels": 1,
        "out_channels": 4,
        "kernel_size": 3,
        "stride": 1,
        "padding": 0,
        "output": [4, 26, 26],
    },
    "pool1": {"kernel_size": 2, "stride": 2, "output": [4, 13, 13]},
    "conv2": {
        "in_channels": 4,
        "out_channels": 8,
        "kernel_size": 3,
        "stride": 1,
        "padding": 0,
        "output": [8, 11, 11],
    },
    "pool2": {"kernel_size": 2, "stride": 2, "output": [8, 5, 5]},
    "flatten_features": 200,
    "fully_connected": {"in_features": 200, "out_features": 10},
}


class SmallCnn(nn.Module):
    """Two-convolution MNIST classifier with explicit observable stages."""

    def __init__(self) -> None:
        super().__init__()
        self.conv1 = nn.Conv2d(1, 4, kernel_size=3, stride=1, padding=0, bias=True)
        self.conv2 = nn.Conv2d(4, 8, kernel_size=3, stride=1, padding=0, bias=True)
        self.fc = nn.Linear(8 * 5 * 5, 10, bias=True)

    def forward_stages(self, x: Tensor) -> OrderedDict[str, Tensor]:
        """Return every stage needed for later C/CPU differential debugging."""
        stages: OrderedDict[str, Tensor] = OrderedDict()
        stages["input"] = x
        stages["conv1"] = self.conv1(stages["input"])
        stages["relu1"] = F.relu(stages["conv1"])
        stages["pool1"] = F.max_pool2d(stages["relu1"], kernel_size=2, stride=2)
        stages["conv2"] = self.conv2(stages["pool1"])
        stages["relu2"] = F.relu(stages["conv2"])
        stages["pool2"] = F.max_pool2d(stages["relu2"], kernel_size=2, stride=2)
        stages["flatten"] = torch.flatten(stages["pool2"], start_dim=1)
        stages["logits"] = self.fc(stages["flatten"])
        return stages

    def forward(self, x: Tensor) -> Tensor:
        return self.forward_stages(x)["logits"]
