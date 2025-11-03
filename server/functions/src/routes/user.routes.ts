import { Router } from "express";
import {
  createUser,
  getUsers,
  getUserByUid,
  updateUser,
  deleteUser,
  getSalonsNearby,
  registerUserComplete,
} from "../controllers/user.controller";

const router = Router();
router.post("/", createUser);
router.get("/", getUsers);
router.post('/register', registerUserComplete);
router.get("/uid/:uid", getUserByUid);
router.put("/:uid", updateUser);
router.delete("/:uid", deleteUser);
router.get("/salons/nearby", getSalonsNearby);

export default router;
