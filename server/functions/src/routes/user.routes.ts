import { Router } from "express";
import {
  createUser,
  getUsers,
  getUserByUid,
  updateUser,
  deleteUser,
  getSalonsNearby,
  registerUserComplete,
  updateFCMToken,
  deleteFCMToken,
} from "../controllers/user.controller";

const router = Router();
router.post("/", createUser);
router.get("/", getUsers);
router.post('/register', registerUserComplete);
router.get("/uid/:uid", getUserByUid);
router.put("/:uid", updateUser);
router.delete("/:uid", deleteUser);
router.get("/salons/nearby", getSalonsNearby);

// FCM Token routes
router.put("/fcm-token", updateFCMToken);
router.delete("/fcm-token", deleteFCMToken);

export default router;
